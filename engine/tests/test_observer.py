import contextlib
import io
import json
import unittest
from mitmproxy.test import tflow
from sendscope_addon import SendScope, reported_filenames, PREFIX_LIMIT, MAX_ACTIVE

class ObserverTests(unittest.TestCase):
    def test_filename_is_not_claimed_from_json(self):
        self.assertEqual(reported_filenames(b'Content-Disposition: form-data; filename="secret.txt"', 'application/json'), [])

    def test_only_basename_retained(self):
        self.assertEqual(reported_filenames(b'Content-Disposition: form-data; name="f"; filename="/private/project/report.csv"\r\n', 'multipart/form-data'), ['report.csv'])

    def test_stream_preserves_bytes_without_persisting_secrets(self):
        observer = SendScope(); flow = tflow.tflow()
        flow.request.headers['content-type'] = 'multipart/form-data; boundary=test'
        flow.request.headers['authorization'] = 'Bearer DO_NOT_STORE'
        flow.request.path = '/private/path?token=DO_NOT_STORE'
        body = b'--test\r\nContent-Disposition: form-data; name="f"; filename="report.txt"\r\n\r\nDO_NOT_STORE'
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            observer.requestheaders(flow)
            stream = flow.request.stream
            self.assertEqual(stream(body), body)
            self.assertEqual(stream(b'x' * (PREFIX_LIMIT * 2)), b'x' * (PREFIX_LIMIT * 2))
            stream(b'')
            self.assertLessEqual(len(observer.active[flow.id]['_prefix']), PREFIX_LIMIT)
            observer.request(flow)
            observer.error(flow)
        self.assertNotIn('DO_NOT_STORE', output.getvalue())
        self.assertNotIn('/private/path', output.getvalue())
        events = [json.loads(line.removeprefix('SENDSCOPE ')) for line in output.getvalue().splitlines()]
        self.assertEqual(events[-1]['bytes'], len(body) + PREFIX_LIMIT * 2)
        self.assertEqual(events[-1]['files'], ['report.txt'])
        self.assertEqual(observer.active, {})

    def test_active_budget_does_not_block_traffic(self):
        observer = SendScope()
        with contextlib.redirect_stdout(io.StringIO()):
            for _ in range(MAX_ACTIVE + 1):
                flow = tflow.tflow(); observer.requestheaders(flow)
        self.assertEqual(len(observer.active), MAX_ACTIVE)
        self.assertIs(flow.request.stream, True)

if __name__ == '__main__': unittest.main()
