# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171227155155) do

  create_table "crono_jobs", force: :cascade do |t|
    t.string "job_id", null: false
    t.text "log", limit: 1073741823
    t.datetime "last_performed_at"
    t.boolean "healthy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_crono_jobs_on_job_id", unique: true
  end

  create_table "orders", force: :cascade do |t|
    t.string "order_id", null: false
    t.string "order_type", null: false
    t.string "status", null: false
    t.integer "count"
    t.string "base_currency", null: false
    t.string "currency", null: false
    t.float "amount", default: 0.0, null: false
    t.float "rate", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_orders_on_order_id"
    t.index ["status"], name: "index_orders_on_status"
  end

  create_table "rate_stacks", force: :cascade do |t|
    t.string "base_currency", null: false
    t.string "currency", null: false
    t.string "rate_type", null: false
    t.float "rate", default: 0.0, null: false
    t.string "change_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_currency"], name: "index_rate_stacks_on_base_currency"
    t.index ["currency"], name: "index_rate_stacks_on_currency"
    t.index ["rate_type"], name: "index_rate_stacks_on_rate_type"
  end

  create_table "trading_states", force: :cascade do |t|
    t.string "name", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_trading_states_on_name"
  end

end
