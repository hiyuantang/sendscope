# Third-party software

SendScope runs [mitmproxy](https://github.com/mitmproxy/mitmproxy) as a separate local inspection engine. mitmproxy is distributed under the [MIT License](https://github.com/mitmproxy/mitmproxy/blob/main/LICENSE), copyright (c) 2013 Aldo Cortesi.

The macOS capture extension and Python dependencies are installed by `script/setup_engine.sh` into the ignored `.runtime` directory. Exact versions are recorded in `engine/requirements.lock`. Their license files and notices remain with the installed packages; SendScope's MIT license does not replace them.

This source repository does not include those third-party binaries or a bundled Python runtime. Any future standalone distribution that includes them must preserve the applicable third-party licenses and notices.

The application icon was generated with OpenAI's image-generation tool. The prompts are recorded in `assets/icon-prompt.txt`.
