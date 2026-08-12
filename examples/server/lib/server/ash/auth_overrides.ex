defmodule Server.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.{Components, SignInLive, ResetLive}


  # If using standard password registration forms
  override Components.Password.RegisterForm do
    set :form_class, "space-y-6"
    set :label_class, "block text-sm font-medium text-gray-900"
    set :register_extra_component, SambaWeb.Components.AltchaExtra
  end
end
