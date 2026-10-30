import json
from pathlib import Path
import tempfile
import threading
import time
import unittest

from bridge import submit, build_parser, command_from_args


class ProtocolTests(unittest.TestCase):
    def test_rename_preserves_spaces_and_punctuation(self):
        args = build_parser().parse_args(['rename_object', 'object-id', 'Stage: Left Wall'])
        self.assertEqual(command_from_args(args), {'action': 'rename_object', 'object_id': 'object-id', 'name': 'Stage: Left Wall'})

    def test_duplicate_omits_unspecified_name(self):
        command = command_from_args(build_parser().parse_args(['duplicate_object', 'object-id']))
        self.assertNotIn('name', command)
        self.assertEqual(command['offset'], [2, 0, 0])

    def test_group_duplicate_requires_explicit_offset(self):
        with self.assertRaises(SystemExit):
            build_parser().parse_args(['duplicate_group', 'group-id', 'New Group'])

    def test_group_commands_keep_member_order_and_negative_offset(self):
        command = command_from_args(build_parser().parse_args(['create_group', 'Walls', 'b', 'a']))
        self.assertEqual(command['object_ids'], ['b', 'a'])
        command = command_from_args(build_parser().parse_args(['duplicate_group', 'g', 'Walls Copy', '--offset', '-4', '0', '2']))
        self.assertEqual(command, {'action': 'duplicate_group', 'group_id': 'g', 'name': 'Walls Copy', 'offset': [-4.0, 0.0, 2.0]})

    def test_disabled_bridge_refuses_submission(self):
        with tempfile.TemporaryDirectory() as project:
            with self.assertRaises(RuntimeError):
                submit(project, {'action': 'status'}, 0.1)

    def test_unclaimed_timeout_cancels_request(self):
        with tempfile.TemporaryDirectory() as project:
            inbox = Path(project) / '.lumina-bridge'
            inbox.mkdir()
            (inbox / 'enabled').touch()
            with self.assertRaises(TimeoutError):
                submit(project, {'action': 'create_primitive'}, 0.01)
            self.assertEqual(list(inbox.glob('*.request.json')), [])

    def test_claim_and_response_correlate_by_unique_id(self):
        with tempfile.TemporaryDirectory() as project:
            inbox = Path(project) / '.lumina-bridge'
            inbox.mkdir()
            (inbox / 'enabled').touch()

            def client():
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    requests = list(inbox.glob('*.request.json'))
                    if requests:
                        request = requests[0]
                        payload = json.loads(request.read_text())
                        request.rename(inbox / (payload['id'] + '.claimed.json'))
                        (inbox / (payload['id'] + '.response.json')).write_text(json.dumps({'ok': True, 'action': payload['action']}))
                        return
                    time.sleep(0.01)

            worker = threading.Thread(target=client)
            worker.start()
            result = submit(project, {'action': 'status'}, 3)
            worker.join()
            self.assertEqual(result, {'ok': True, 'action': 'status'})


if __name__ == '__main__':
    unittest.main()
