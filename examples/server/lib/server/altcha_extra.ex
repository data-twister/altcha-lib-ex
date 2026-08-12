defmodule Server.Components.AltchaExtra do
  use AshAuthentication.Phoenix.Overrides
  use Phoenix.Component

  attr :form, Phoenix.HTML.Form, required: true

  override AshAuthentication.Phoenix.Components.Password do
    set :register_extra_component, &__MODULE__.register_extra/1
  end

  def register_extra(assigns) do
    ~H"""
    <div class="mt-4" id="altcha-root" phx-hook="AltchaHook">
      <%!--
        We use phx-update="ignore" on the outer wrapper so LiveView never
        touches or diffs the altcha widget or its hidden input once mounted.
      --%>
      <div id="altcha-wrapper" phx-update="ignore">
        <input type="hidden" name="user[altcha]" id="altcha-token-input" value="" />
        <altcha-widget challenge="/challenge"></altcha-widget>
      </div>
    </div>
    """
  end
end
