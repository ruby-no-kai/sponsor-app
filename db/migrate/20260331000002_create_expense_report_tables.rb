# frozen_string_literal: true

class CreateExpenseReportTables < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_reports do |t|
      t.references :sponsorship, null: false, foreign_key: true, index: {unique: true}
      t.decimal :total_amount, precision: 12, scale: 2, default: 0, null: false
      t.decimal :total_tax_amount, precision: 12, scale: 2, default: 0, null: false
      t.string :status, null: false, default: 'draft'
      t.integer :revision, null: false, default: 0

      t.timestamps
    end

    create_table :expense_report_submissions do |t|
      t.references :expense_report, null: false, foreign_key: true, index: false
      t.integer :revision, null: false
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end
    add_index :expense_report_submissions, [:expense_report_id, :revision], unique: true, name: 'idx_expense_report_submissions_unique'

    create_table :expense_report_reviews do |t|
      t.references :expense_report_submission, null: false, foreign_key: true
      t.references :staff, foreign_key: true
      t.string :action, null: false
      t.text :comment

      t.timestamps
    end

    create_table :expense_files do |t|
      t.references :sponsorship, null: false, foreign_key: true
      t.string :prefix, null: false
      t.string :handle, null: false
      t.string :extension
      t.string :version_id, null: false, default: ''
      t.string :checksum_sha256, null: false, default: ''
      t.datetime :last_modified_at
      t.string :filename
      t.string :content_type

      t.timestamps
    end
    add_index :expense_files, :handle

    create_table :expense_line_items do |t|
      t.references :expense_report, null: false, foreign_key: true, index: false
      t.string :title, null: false
      t.text :notes
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :tax_rate, precision: 5, scale: 4
      t.decimal :tax_amount, precision: 12, scale: 2, null: false, default: 0
      t.boolean :preliminal, null: false, default: false
      t.integer :position, null: false

      t.timestamps
    end
    add_index :expense_line_items, [:expense_report_id, :position]

    create_table :expense_line_item_files do |t|
      t.references :expense_line_item, null: false, foreign_key: true, index: false
      t.references :expense_file, null: false, foreign_key: true

      t.timestamps
    end
    add_index :expense_line_item_files, [:expense_line_item_id, :expense_file_id], unique: true, name: 'idx_line_item_files_unique'
  end
end
