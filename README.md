# discourse-railway

Thin wrapper over the official [Discourse](https://github.com/discourse/discourse) image for Railway. The upstream image runs nginx,
unicorn and sidekiq in one container and listens on 80; the wrapper rewrites nginx's listener to Railway's injected `PORT`, hands the
`/shared` volume to Discourse's uid, and checks that strong secrets and the database and Redis settings are present before it starts.
Once the app answers it creates the administrator from `ADMIN_EMAIL` and `ADMIN_PASSWORD`, an API key from `ADMIN_API_KEY`, and closes
public sign-up (site settings plus an nginx rule that refuses an anonymous POST to the account-creation routes). Used by the Discourse
template on the Railway marketplace.
