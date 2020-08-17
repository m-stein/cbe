/*
 * Copyright (C) 2019 Genode Labs GmbH, Componolit GmbH, secunet AG
 *
 * This file is part of the Consistent Block Encrypter project, which is
 * distributed under the terms of the GNU Affero General Public License
 * version 3.
 */

/* Genode includes */
#include <base/attached_rom_dataspace.h>
#include <base/component.h>
#include <base/heap.h>
#include <block_session/connection.h>

/* CBE-init includes */
#include <cbe_init/library.h>
#include <cbe_init/configuration.h>

/* CBE external trust anchor */
#include <cbe/external_ta.h>


using namespace Genode;

class Main
{
	private:

		enum { TX_BUF_SIZE = Block::Session::TX_QUEUE_SIZE * Cbe::BLOCK_SIZE };

		Env                  &_env;
		Heap                  _heap        { _env.ram(), _env.rm() };
		Allocator_avl         _blk_alloc   { &_heap };
		Block::Connection<>   _blk         { _env, &_blk_alloc, TX_BUF_SIZE };
		Signal_handler<Main>  _blk_handler { _env.ep(), *this, &Main::_execute };
		Cbe::Request          _blk_req     { };
		Cbe::Io_buffer        _blk_buf     { };
		Cbe_init::Library     _cbe_init    { };

		External::Trust_anchor _trust_anchor { };

		Genode::size_t        _blk_ratio   {
			Cbe::BLOCK_SIZE / _blk.info().block_size };

		void _execute()
		{
			for (bool progress { true }; progress; ) {

				progress = false;

				_cbe_init.execute(_blk_buf);
				if (_cbe_init.execute_progress()) {
					progress = true;
				}

				Cbe::Request const req {
					_cbe_init.peek_completed_client_request() };

				if (req.valid()) {
					_cbe_init.drop_completed_client_request(req);
					if (req.success()) {
						_env.parent().exit(0);
					} else {
						error("request was not successful");;
						_env.parent().exit(-1);
					}
				}

				progress |= _trust_anchor.execute();

				using Op = Cbe::Trust_anchor_request::Operation;

				while (true) {

					Cbe::Trust_anchor_request const request =
						_cbe_init.peek_generated_ta_request();

					if (!request.valid()) { break; }
					if (!_trust_anchor.request_acceptable()) { break; }

					switch (request.operation()) {
					case Op::CREATE_KEY:
						_trust_anchor.submit_create_key_request(request);
						break;
					case Op::SECURE_SUPERBLOCK:
					{
						Cbe::Hash const sb_hash = _cbe_init.peek_generated_ta_sb_hash(request);
						_trust_anchor.submit_secure_superblock_request(request, sb_hash);
						break;
					}
					case Op::ENCRYPT_KEY:
					{
						Cbe::Key_plaintext_value const pk =
							_cbe_init.peek_generated_ta_key_value_plaintext(request);

						_trust_anchor.submit_encrypt_key_request(request, pk);
						break;
					}
					case Op::DECRYPT_KEY:
					{
						Cbe::Key_ciphertext_value const ck =
							_cbe_init.peek_generated_ta_key_value_ciphertext(request);

						_trust_anchor.submit_decrypt_key_request(request, ck);
						break;
					}
					case Op::INVALID:
						/* never reached */
						break;
					}
					_cbe_init.drop_generated_ta_request(request);
					progress |= true;
				}

				while (true) {

					Cbe::Trust_anchor_request const request =
						_trust_anchor.peek_completed_request();

					if (!request.valid()) { break; }

					switch (request.operation()) {
					case Op::CREATE_KEY:
					{
						Cbe::Key_plaintext_value const pk =
							_trust_anchor.peek_completed_key_value_plaintext(request);

						_cbe_init.mark_generated_ta_create_key_request_complete(request, pk);
						break;
					}
					case Op::SECURE_SUPERBLOCK:
					{
						_cbe_init.mark_generated_ta_secure_sb_request_complete(request);
						break;
					}
					case Op::ENCRYPT_KEY:
					{
						Cbe::Key_ciphertext_value const ck =
							_trust_anchor.peek_completed_key_value_ciphertext(request);

						_cbe_init.mark_generated_ta_encrypt_key_request_complete(request, ck);
						break;
					}
					case Op::DECRYPT_KEY:
					{
						Cbe::Key_plaintext_value const pk =
							_trust_anchor.peek_completed_key_value_plaintext(request);

						_cbe_init.mark_generated_ta_decrypt_key_request_complete(request, pk);
						break;
					}
					case Op::INVALID:
						/* never reached */
						break;
					}
					_trust_anchor.drop_completed_request(request);
					progress |= true;
				}

				struct Invalid_io_request : Exception { };

				while (_blk.tx()->ready_to_submit()) {

					Cbe::Io_buffer::Index data_index { 0 };
					Cbe::Request request { };
					_cbe_init.has_io_request(request, data_index);

					if (!request.valid()) {
						break;
					}
					if (_blk_req.valid()) {
						break;
					}
					try {
						request.tag(data_index.value);
						Block::Packet_descriptor::Opcode op;
						switch (request.operation()) {
						case Cbe::Request::Operation::READ:
							op = Block::Packet_descriptor::READ;
							break;
						case Cbe::Request::Operation::WRITE:
							op = Block::Packet_descriptor::WRITE;
							break;
						case Cbe::Request::Operation::SYNC:
							op = Block::Packet_descriptor::SYNC;
							break;
						default:
							throw Invalid_io_request();
						}
						Block::Packet_descriptor packet {
							_blk.alloc_packet(Cbe::BLOCK_SIZE), op,
							request.block_number() * _blk_ratio,
							request.count() * _blk_ratio };

						if (request.operation() == Cbe::Request::Operation::WRITE) {
							*reinterpret_cast<Cbe::Block_data*>(
								_blk.tx()->packet_content(packet)) =
									_blk_buf.item(data_index);
						}
						_blk.tx()->try_submit_packet(packet);
						_blk_req = request;
						_cbe_init.io_request_in_progress(data_index);
						progress = true;
					}
					catch (Block::Session::Tx::Source::Packet_alloc_failed) {
						break;
					}
				}

				while (_blk.tx()->ack_avail()) {

					Block::Packet_descriptor packet =
						_blk.tx()->try_get_acked_packet();

					if (!_blk_req.valid()) {
						break;
					}

					bool const read  =
						packet.operation() == Block::Packet_descriptor::READ;

					bool const write =
						packet.operation() == Block::Packet_descriptor::WRITE;

					bool const sync =
						packet.operation() == Block::Packet_descriptor::SYNC;

					bool const op_match =
						(read && _blk_req.read()) ||
						(write && _blk_req.write()) ||
						(sync && _blk_req.sync());

					bool const bn_match =
						packet.block_number() / _blk_ratio == _blk_req.block_number();

					if (!bn_match || !op_match) {
						break;
					}

					_blk_req.success(packet.succeeded());

					Cbe::Io_buffer::Index const data_index { _blk_req.tag() };
					bool                  const success    { _blk_req.success() };

					if (read && success) {
						_blk_buf.item(data_index) =
							*reinterpret_cast<Cbe::Block_data*>(
								_blk.tx()->packet_content(packet));
					}
					_cbe_init.io_request_completed(data_index, success);
					_blk.tx()->release_packet(packet);
					_blk_req = Cbe::Request();
					progress = true;
				}
			}
			_blk.tx()->wakeup();
		}

	public:

		Main(Env &env)
		:
			_env { env }
		{
			if (_blk_ratio == 0) {
				error("backend block size not supported");
				_env.parent().exit(-1);
				return;
			}

			Attached_rom_dataspace  config_rom { _env, "config" };
			Xml_node         const &config     { config_rom.xml() };
			try {
				Cbe_init::Configuration const cfg { config };
				if (!_cbe_init.client_request_acceptable()) {
					error("failed to submit request");
					_env.parent().exit(-1);
				}
				_cbe_init.submit_client_request(
					Cbe::Request(
						Cbe::Request::Operation::READ,
						false, 0, 0, 0, 0, 0),
					cfg.vbd_nr_of_lvls() - 1,
					cfg.vbd_nr_of_children(),
					cfg.vbd_nr_of_leafs(),
					cfg.ft_nr_of_lvls() - 1,
					cfg.ft_nr_of_children(),
					cfg.ft_nr_of_leafs());

				_blk.tx_channel()->sigh_ack_avail(_blk_handler);
				_blk.tx_channel()->sigh_ready_to_submit(_blk_handler);

				_execute();
			}
			catch (Cbe_init::Configuration::Invalid) {
				error("bad configuration");
				_env.parent().exit(-1);
			}
		}

		~Main()
		{
			_blk.tx_channel()->sigh_ack_avail(Signal_context_capability());
			_blk.tx_channel()->sigh_ready_to_submit(Signal_context_capability());
		}
};

extern "C" int memcmp(const void *p0, const void *p1, Genode::size_t size)
{
	return Genode::memcmp(p0, p1, size);
}

extern "C" void adainit();

void Component::construct(Genode::Env &env)
{
	env.exec_static_constructors();

	Cbe::assert_valid_object_size<Cbe_init::Library>();

	cbe_init_cxx_init();

	static Main main(env);
}
