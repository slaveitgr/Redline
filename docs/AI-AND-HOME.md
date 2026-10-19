# AI and Home integration

Redline Chat is an original Qt UI using the documented Ollama API (`GET /api/tags`, `POST /api/chat`, non-streamed replies). Requests only occur on Refresh or Send, target 127.0.0.1:11434, bypass proxies and reject redirects. No installation, model pull, shell execution, or automatic system changes are implemented. Known cloud model names and remote metadata are excluded from the model picker. This is a local endpoint integration, not an independent audit of a user's Ollama configuration.

Chat history is session-only and selectable as plain text. The last 20 messages are sent with bounded content. A hardware snapshot (sensor values and CPU name) is included only when its unchecked-by-default option is selected; no personal documents are loaded. Changing models clears the conversation. Requests support cancellation, errors, size limits, and timeouts. Long generations are non-streamed in this first implementation.

Apps lists the local models reported by the service and can select one for Chat. It is not a complete AI application marketplace. There is no document RAG, image generation, or automatic model memory suspension yet. Real generation performance on the user's GPU has not been validated; the transport is tested against a local fixture server.

Home retains the three-column Adrenalin-style structure with original Redline assets, actual installed games, live GPU/temperature values and navigation to Metrics, game details, capture workspace, system settings, and Chat. Suggested questions are drafts, not automatically sent. Play time/FPS remain unavailable when unmeasured; capture remains visibly unconnected.

References: https://docs.ollama.com/api/chat and https://docs.ollama.com/api/tags . AMD feature comparison: https://www.amd.com/en/resources/support-articles/faqs/DH3-045.html .

Verification: `tests/test_local_assistant.cpp` uses a fixture on an unused 127.0.0.1:11434; exits 77 rather than stopping an existing service. It checks model discovery/filtering, a real HTTP chat request and reply, invalid-model rejection, malformed JSON, cancellation, and no automatic startup requests. The native preview suite checks AI/Home navigation in addition to existing application checks. Hardware writes are not exercised by this UI pass.
