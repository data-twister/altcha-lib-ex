defmodule Server.Accounts.User.Actions do
  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    defaults [:read]

    create :register_with_password do
      description "Register a new user with an email and password."

      argument :email, :ci_string do
        allow_nil? false
      end

      argument :password, :string do
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        allow_nil? false
        sensitive? true
      end

      argument :altcha, :string, allow_nil?: false
      change Server.Changes.VerifyAltcha

      change set_attribute(:email, arg(:email))

      change fn changeset, _context ->
        case Ash.Changeset.get_argument(changeset, :email) do
          email when is_binary(email) or not is_nil(email) ->
            [username | _] = String.split(to_string(email), "@")
            Ash.Changeset.force_change_attribute(changeset, :username, username)

          _ ->
            changeset
        end
      end

      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange

      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      metadata :token, :string do
        allow_nil? false
      end
    end

end
end
