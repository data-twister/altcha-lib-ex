defmodule Server.Changes.VerifyAltcha do
  use Ash.Resource.Change

  alias Altcha.V2
  alias Altcha.V2.VerifySolutionOptions

  @hmac_secret System.get_env("ALTCHA_HMAC_SECRET", "change-me-in-production")
  @hmac_key_secret System.get_env("ALTCHA_HMAC_KEY_SECRET", "change-me-in-production-2")

  @impl true
  def change(changeset, _opts, _context) do
    altcha_payload = Ash.Changeset.get_argument(changeset, :altcha)

    cond do
      is_nil(altcha_payload) or altcha_payload == "" ->
        Ash.Changeset.add_error(changeset, field: :altcha, message: "Missing altcha payload.")

      true ->
        case decode_altcha(altcha_payload) do
          :error ->
            Ash.Changeset.add_error(changeset,
              field: :altcha,
              message: "Malformed altcha payload."
            )

          {:client, %V2.Payload{challenge: challenge, solution: solution}} ->
            result =
              V2.verify_solution(%VerifySolutionOptions{
                challenge: challenge,
                solution: solution,
                hmac_signature_secret: @hmac_secret,
                hmac_key_signature_secret: @hmac_key_secret
              })

            if result.verified do
              changeset
            else
              Ash.Changeset.add_error(changeset,
                field: :altcha,
                message: "Invalid CAPTCHA solution."
              )
            end

          {:server_signature, raw} ->
            {result, _verification_data} = V2.verify_server_signature(raw, @hmac_secret)

            if result.verified do
              changeset
            else
              Ash.Changeset.add_error(changeset,
                field: :altcha,
                message: "Invalid server signature."
              )
            end
        end
    end
  end

  defp decode_altcha(encoded) do
    with {:ok, raw} <- Base.decode64(encoded),
         {:ok, map} <- Jason.decode(raw) do
      if Map.has_key?(map, "verificationData") do
        {:server_signature, map}
      else
        case V2.decode_payload(encoded) do
          nil -> :error
          payload -> {:client, payload}
        end
      end
    else
      _ -> :error
    end
  end
end
