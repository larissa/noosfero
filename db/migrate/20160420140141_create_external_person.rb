class CreateExternalPerson < ActiveRecord::Migration
  def change
    create_table :external_people do |t|
      t.string :name
      t.string :identifier
      t.string :source
      t.string :email_md5_hash
      t.integer :environment_id
      t.boolean :visible, default: true
    end
  end
end
