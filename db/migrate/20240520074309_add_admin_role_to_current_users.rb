class AddAdminRoleToCurrentUsers < ActiveRecord::Migration[7.2]
  def up
    # Use SQL directly to avoid loading User model which has enum validations
    # that may fail if columns don't exist yet during migrations
    execute "UPDATE users SET role = 'admin' WHERE role IS NULL OR role = ''"
  end
end
