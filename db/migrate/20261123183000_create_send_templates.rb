class CreateSendTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :send_templates do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :name, null: false
      t.string :subject
      t.text :body, null: false

      t.timestamps
    end

    add_reference :recurring_documents, :send_template, foreign_key: true
  end
end
