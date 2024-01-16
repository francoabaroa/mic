defmodule InstagramService do
  def get_auth_url(client_id, redirect_uri, auth_url) do
    "#{auth_url}?client_id=#{client_id}&redirect_uri=#{redirect_uri}&scope=user_profile,user_media&response_type=code"
  end

  def exchange_code_for_token(client_id, client_secret, redirect_uri, code, token_url) do
    body = [
      client_id: client_id,
      client_secret: client_secret,
      grant_type: "authorization_code",
      redirect_uri: redirect_uri,
      code: code
    ]

    HTTPoison.post(token_url, {:form, body}, [])
  end

  def get_user_data(user_id, access_token, api_url) do
    HTTPoison.get("#{api_url}/#{user_id}?fields=id,username&access_token=#{access_token}")
  end
end
