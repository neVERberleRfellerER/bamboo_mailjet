defmodule Bamboo.MailjetAdapter do
  @moduledoc """
  Sends email using Mailjet's API.

  Use this adapter to send emails through Mailjet's API. Requires that both an API and
  a private API keys are set in the config.

  ## Example config

      # In config/config.exs, or config.prod.exs, etc.
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MailjetAdapter,
        api_key: "my_api_key",
        api_private_key: "my_private_api_key"

      # Define a Mailer. Maybe in lib/my_app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end

  """

  @service_name "Mailjet"
  @default_base_uri "https://api.mailjet.com/v3.1"
  @send_message_path "/send"
  @behaviour Bamboo.Adapter

  import Bamboo.ApiError

  alias Bamboo.Email

  @impl true
  def deliver(%Bamboo.Email{} = email, config) do
    config = handle_config(config)
    body = email |> to_mailjet_body() |> Bamboo.json_library().encode!()
    url = [base_uri(), @send_message_path]

    case :hackney.post(url, headers(config), body, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        {:error, build_api_error(@service_name, response, body)}

      {:ok, status, headers, response} ->
        {:ok, %{status_code: status, headers: headers, body: response}}

      {:error, reason} ->
        {:error, build_api_error(inspect(reason))}
    end
  end

  @impl true
  def handle_config(config) do
    config
    |> Map.put(:api_key, get_setting(config, :api_key))
    |> Map.put(:domain, get_setting(config, :api_private_key))
  end

  @impl true
  def supports_attachments?, do: true

  defp headers(config) do
    [{"Content-Type", "application/json"}, {"Authorization", "Basic #{auth_token(config)}"}]
  end

  defp auth_token(%{api_key: api_key, api_private_key: api_private_key}) do
    Base.encode64("#{api_key}:#{api_private_key}")
  end

  defp get_setting(config, key) do
    config[key]
    |> case do
      {:system, var} ->
        System.get_env(var)

      value ->
        value
    end
    |> case do
      value when value in [nil, ""] ->
        raise_missing_setting_error(config, key)

      value ->
        value
    end
  end

  defp raise_missing_setting_error(config, setting) do
    raise ArgumentError, """
    There was no #{setting} set for the Mailjet adapter.
    * Here are the config options that were passed in:
    #{inspect(config)}
    """
  end

  defp to_mailjet_body(%Email{} = email) do
    message_body =
      %{}
      |> put_from(email)
      |> put_subject(email)
      |> put_html_body(email)
      |> put_text_body(email)
      |> put_to(email)
      |> put_cc(email)
      |> put_bcc(email)
      |> put_template_id(email)
      |> put_template_language(email)
      |> put_vars(email)
      |> put_custom_id(email)
      |> put_event_payload(email)
      |> put_attachments(email)

    %{"Messages" => [message_body]}
  end

  defp prepare_recipients(recipients),
    do: Enum.map(recipients, &prepare_recipient/1)

  defp prepare_recipient({name, address}) when name in [nil, "", ''] do
    %{"Email" => address}
  end

  defp prepare_recipient({name, address}) do
    %{"Name" => name, "Email" => address}
  end

  defp prepare_sender(sender), do: prepare_recipient(sender)

  defp put_from(body, %Email{from: {name, address}}) do
    Map.put(body, "From", prepare_sender({name, address}))
  end

  defp put_from(body, %Email{from: address}) when is_binary(address) do
    Map.put(body, "From", prepare_sender({nil, address}))
  end

  defp put_to(body, %Email{to: []}), do: body

  defp put_to(body, %Email{to: to}) do
    Map.put(body, "To", prepare_recipients(to))
  end

  defp put_cc(body, %Email{cc: []}), do: body

  defp put_cc(body, %Email{cc: cc}),
    do: Map.put(body, "Cc", prepare_recipients(cc))

  defp put_bcc(body, %Email{bcc: []}), do: body

  defp put_bcc(body, %Email{bcc: bcc}),
    do: Map.put(body, "Bcc", prepare_recipients(bcc))

  defp put_subject(body, %Email{subject: nil}), do: body

  defp put_subject(body, %Email{subject: subject}),
    do: Map.put(body, "Subject", subject)

  defp put_html_body(body, %Email{html_body: nil}), do: body

  defp put_html_body(body, %Email{html_body: html_body}),
    do: Map.put(body, "HTMLPart", html_body)

  defp put_text_body(body, %Email{text_body: nil}), do: body

  defp put_text_body(body, %Email{text_body: text_body}),
    do: Map.put(body, "TextPart", text_body)

  defp put_template_id(body, %Email{private: %{mj_templateid: id}}),
    do: Map.put(body, "TemplateID", id)

  defp put_template_id(body, _email), do: body

  defp put_template_language(body, %Email{private: %{mj_templatelanguage: active}}),
    do: Map.put(body, "TemplateLanguage", active)

  defp put_template_language(body, _email), do: body

  defp put_vars(body, %Email{private: %{mj_vars: vars}}),
    do: Map.put(body, "Variables", vars)

  defp put_vars(body, _email), do: body

  defp put_custom_id(body, %Email{private: %{mj_custom_id: custom_id}}),
    do: Map.put(body, "CustomID", custom_id)

  defp put_custom_id(body, _email), do: body

  defp put_event_payload(body, %Email{private: %{mj_event_payload: event_payload}}),
    do: Map.put(body, "EventPayload", event_payload)

  defp put_event_payload(body, _email), do: body

  defp put_attachments(body, %Email{attachments: []}), do: body

  defp put_attachments(body, %Email{attachments: attachments}) do
    transformed =
      attachments
      |> Enum.reverse()
      |> Enum.map(fn attachment ->
        %{
          "Filename" => attachment.filename,
          "ContentType" => attachment.content_type,
          "Base64Content" => Base.encode64(attachment.data)
        }
      end)

    Map.put(body, "Attachments", transformed)
  end

  defp base_uri do
    Application.get_env(:bamboo, :mailjet_base_uri) || @default_base_uri
  end
end
