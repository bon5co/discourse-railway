# frozen_string_literal: true
# Runs once the app answers, and again on every redeploy. Creates the administrator only when it does not exist (a login the
# owner changed later is left alone), makes sure the API key from ADMIN_API_KEY exists for that administrator, and closes sign-up.
email = ENV.fetch("ADMIN_EMAIL")
initial_login = ENV.fetch("ADMIN_PASSWORD")
api_key = ENV.fetch("ADMIN_API_KEY")

SiteSetting.has_login_hint = false
SiteSetting.allow_new_registrations = false
SiteSetting.invite_only = true
SiteSetting.force_https = true
SiteSetting.contact_email = email if SiteSetting.contact_email.blank?
SiteSetting.notification_email = "noreply@#{GlobalSetting.hostname}" if SiteSetting.notification_email.blank?

admin = User.find_by_email(email)
if admin.nil?
  admin = User.new(email: email, username: "admin", password: initial_login, active: true, approved: true)
  admin.save!
  puts "[railway] created administrator #{email}"
else
  puts "[railway] administrator #{email} exists, left unchanged"
end
admin.grant_admin! unless admin.admin?
admin.change_trust_level!(4) if admin.trust_level < 4
admin.email_tokens.update_all(confirmed: true)
admin.activate

if ApiKey.with_key(api_key).exists?
  puts "[railway] API key present"
else
  record =
    ApiKey.new(
      description: "railway",
      user: admin,
      created_by: admin,
      key_hash: ApiKey.hash_key(api_key),
      truncated_key: api_key[0..3],
    )
  record.save!
  puts "[railway] created API key"
end
