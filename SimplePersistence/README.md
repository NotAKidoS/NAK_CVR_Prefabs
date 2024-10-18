Description
---

Drag-and-drop persistence for UI Toggle states, GameObject states, and Transform positions.

Technical Details
---

- Parses BoundObjects for UI Toggle, GameObject, and Transform references to save and load their states automatically.
- Checks one object for changes every 5 frames to avoid performance issues.
- Works around several CVR Lua bugs and limitations...

Relevant Feedback Posts
---

- [[Persistence] Blows up deserializing when illegal characters are used.](https://feedback.abinteractive.net/p/persistance-blows-up-deserializing-when-illegal-characters-are-used)
- [[Persistence] Worlds save persistence data to same file (empty guid).](https://feedback.abinteractive.net/p/persistance-worlds-save-persistance-data-to-same-file-empty-guid?b=cvr-exp-bugreports)
- [[Persistence] Returned Table from GetTable cannot be modified.](https://feedback.abinteractive.net/p/persistance-returned-table-from-gettable-cannot-be-modified?b=cvr-exp-bugreports)
- [[Scripting] RCC/UI/TMP Module bindings do not inherit MonoBehaviour/Behaviour bindings.](https://feedback.abinteractive.net/p/scripting-rcc-ui-tmp-module-bindings-do-not-inherit-monobehaviour-behaviour-bindings?b=cvr-exp-bugreports)
- [[Scripting] Cannot reliably save persistence values in OnDestroy. Please provide alternatives.](https://feedback.abinteractive.net/p/cannot-reliably-save-persistance-values-in-ondestroy-please-provide-alternatives?b=cvr-exp-bugreports)
- [[Scripting] Please provide a method for getting the type of an object via scripting.](https://feedback.abinteractive.net/p/please-provide-a-method-for-getting-the-type-of-an-object-via-scripting?b=cvr-exp-bugreports)