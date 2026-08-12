# ALTCHA Elixir Library

A lightweight Elixir library for creating and verifying [ALTCHA](https://altcha.org) challenges.

## Compatibility

- Elixir 1.17+ (OTP 26+)

## Examples

- [`examples/server/`](/examples/server/)
- [`examples/argon2.exs`](/examples/argon2.exs)
- [`examples/server/ash`](/examples/server/ash)

## Installation

```elixir
defp deps do
  [
    {:altcha, "~> 2.0"}
  ]
end
```

**Install ALTCHA**

   ```bash
   mix ALTCHA.install #  --version 3.2.1
   # ... or: npm install altcha --prefix assets
   ```

3. **Add `altcha.install` to `assets.setup` in `mix.exs`** (if using Mix installer):

   ```elixir
   "assets.setup": ["altcha.install", ... ]
   ```

4. **Register JavaScript hook (optional if using liveview)** in your `app.js`:

   ```javascript
   import altcha;
   
   let Hooks = {};
   
   Hooks.AltchaHook = {
    mounted() {
    const widget = this.el.querySelector("altcha-widget");
    const input = this.el.querySelector("#altcha-token-input");

    if (widget && input) {
      widget.addEventListener("statechange", (event) => {
        const { state, payload } = event.detail || {};
        console.log(`[Altcha] State: ${state}, Payload:`, payload);

        if (state === "verified" && payload) {
          input.value = payload;
        } else if (state === "error") {
          input.value = "";
        }
      });
    }
    }
    };

   const liveSocket = new LiveSocket('/live', Socket, {
     hooks: Hooks,
   });
   ```

5. **add to endpoint.ex**
```elixir
plug :serve_altcha_challenge
plug Web.Router

def serve_altcha_challenge(%Plug.Conn{method: "GET", path_info: ["challenge"]} = conn, _opts) do
hmac_secret = System.get_env("ALTCHA_HMAC_SECRET", "change-me-in-production")
hmac_key_secret = System.get_env("ALTCHA_HMAC_KEY_SECRET", "change-me-in-production-2")

    counter = Enum.random(5_000..10_000)

    challenge =
      Altcha.V2.create_challenge(%Altcha.V2.CreateChallengeOptions{
        algorithm: "PBKDF2/SHA-256",
        cost: 5_000,
        counter: counter,
        expires_at: DateTime.to_unix(DateTime.utc_now(), :second) + 600,
        hmac_signature_secret: hmac_secret,
        hmac_key_signature_secret: hmac_key_secret
      })

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(challenge))
    |> halt()
end

# Fallthrough clause so other routes like /register pass through safely to the router
def serve_altcha_challenge(conn, _opts), do: conn
```
or use the example router

```elixir
plug Server.Router
plug Web.Router
```

## Versions

The library supports two proof-of-work versions:

| Module | Algorithm | Use with |
|--------|-----------|----------|
| `Altcha.V1` | Hash-based (`SHA-256` etc.) | ALTCHA widget v1 |
| `Altcha.V2` | Key-derivation-based (`PBKDF2`, iterative `SHA`) | ALTCHA widget v2 |

The top-level `Altcha` module delegates to `Altcha.V1` for backward compatibility.

---

## V2 Usage

### Creating a challenge

```elixir
challenge = Altcha.V2.create_challenge(%Altcha.V2.CreateChallengeOptions{
  algorithm: "PBKDF2/SHA-256",
  cost: 10_000,
  hmac_signature_secret: "your-secret"
})

# Send as JSON to the client
Jason.encode!(challenge)
```

For deterministic mode (random counter, faster server-side verification):

```elixir
challenge = Altcha.V2.create_challenge(%Altcha.V2.CreateChallengeOptions{
  algorithm: "PBKDF2/SHA-256",
  cost: 5_000,
  counter: Enum.random(5_000..10_000),
  expires_at: DateTime.to_unix(DateTime.utc_now(), :second) + 600,
  hmac_signature_secret: "your-secret",
  hmac_key_signature_secret: "your-key-secret"
})
```

With `counter` and `hmac_key_signature_secret`, the server pre-computes the expected derived key and signs it. Verification then checks the HMAC of the submitted key instead of re-running the key derivation.

### Verifying a solution

The client submits a Base64-encoded JSON payload containing the challenge and solution:

```elixir
# Decode the client payload
payload = Altcha.V2.decode_payload(params["altcha"])

result = Altcha.V2.verify_solution(%Altcha.V2.VerifySolutionOptions{
  challenge: payload.challenge,
  solution: payload.solution,
  hmac_signature_secret: "your-secret",
  hmac_key_signature_secret: "your-key-secret"  # optional
})

result.verified       # true / false
result.expired        # true if the challenge has expired
result.invalid_signature  # true if the challenge was tampered with
result.invalid_solution   # true if the solution is incorrect
```

### Verifying a server signature

```elixir
{result, verification_data} = Altcha.V2.verify_server_signature(params["altcha"], "your-secret")

result.verified           # true / false
verification_data["email"]      # values parsed from verificationData
verification_data["verified"]   # boolean
verification_data["expire"]     # integer Unix timestamp
```

`verify_server_signature/2` accepts a `%Altcha.V2.ServerSignaturePayload{}` struct, a plain map, a raw JSON string, or a Base64-encoded JSON string.

### Verifying form fields hash

```elixir
Altcha.V2.verify_fields_hash(form_data, ["email", "message"], fields_hash, "SHA-256")
```

### Supported algorithms

| Algorithm string | Description |
|-----------------|-------------|
| `"SHA-256"` / `"SHA-384"` / `"SHA-512"` | Iterative SHA hashing (built-in) |
| `"PBKDF2/SHA-256"` / `"PBKDF2/SHA-384"` / `"PBKDF2/SHA-512"` | PBKDF2 (requires OTP 24+) |
| Custom | Pass a `derive_key_fn` option |

### Custom key derivation

For algorithms not built-in (e.g. Scrypt, Argon2id), provide a `derive_key_fn`:

```elixir
Altcha.V2.create_challenge(%Altcha.V2.CreateChallengeOptions{
  algorithm: "SCRYPT",
  cost: 16_384,
  memory_cost: 8,
  derive_key_fn: fn params, salt, password ->
    # return derived key as binary
  end,
  hmac_signature_secret: "your-secret"
})
```

---

## V1 Usage

```elixir
challenge = Altcha.V1.create_challenge(%Altcha.V1.ChallengeOptions{
  hmac_key: "your-secret",
  max_number: 100_000,
  expires: DateTime.to_unix(DateTime.utc_now(), :second) + 600
})

# Verify a solution submitted by the client
Altcha.V1.verify_solution(params["altcha"], "your-secret")

# Verify a server signature
{verified, verification_data} = Altcha.V1.verify_server_signature(params["altcha"], "your-secret")

# Verify form fields hash
Altcha.V1.verify_fields_hash(form_data, ["email", "message"], fields_hash, :sha256)
```
---

## License

MIT
