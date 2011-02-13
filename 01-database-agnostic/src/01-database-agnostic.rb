require 'rubygems'
require 'active_record'

# Setup logging with ActiveRecord
require 'logger'
def setup_log(destination=STDOUT)
  puts "A log of the sql queries will be outputted to: #{destination}"
  
  if destination != STDOUT
    File.delete(destination) if File.exist?(destination)
  end
  
  log = Logger.new destination
  log.level = Logger::DEBUG
  ActiveRecord::Base.logger = log
end

# DETECT ARGV SETUP OF WHICH DATABASE TO USE
db = nil
ARGV.each{ |a| db = a.split("=").last if a.split("=").first.to_s.downcase == "database" }
if db.nil? || !db[/(mysql|sqlite)/]
  abort "PLEASE SPECIFY EITHER: database=mysql or database=sqlite" # We're done here
end

# Setup mysql if specified
if db == "mysql" 
  puts "**** SETTING UP MySQL ****"
  
  setup_log File.expand_path(File.dirname(__FILE__) + "/mysql.log")
  
  require 'mysql'
  mysql_config = {  :adapter  => "mysql",
                    :host     => "localhost",
                    :username => "root",
                    :password => "",
                    :database => "01-database-agnostic"  }

  # Connect without db, drop, then create the database
  ActiveRecord::Base.establish_connection(mysql_config.merge(:database => nil))
  ActiveRecord::Base.connection.drop_database(mysql_config[:database])
  ActiveRecord::Base.connection.create_database(mysql_config[:database], {:charset  => 'utf8'})

  # Connect with db
  ActiveRecord::Base.establish_connection(mysql_config)
end

# Setup sqlite db if specified
if db == "sqlite"
  puts "**** SETTING UP SQLITE ****"
  
  setup_log File.expand_path(File.dirname(__FILE__) + "/sqlite.log")
  
  require 'sqlite3'
  sqlite_file = File.expand_path(File.dirname(__FILE__) + "/01-database-agnostic.sqlite")
  File.delete(sqlite_file) if File.exist?(sqlite_file) # Remove the sqlite db if it exists

  ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3",
    :database  => sqlite_file
  )
end

# Setup the migration class that will build the widgets table when called
# This migration will work regardless of which db is chosen above
class CreateWidgets < ActiveRecord::Migration
  def self.up
    create_table :widgets do |t|
      t.string :name

      t.timestamps
    end
  end
  
  def self.down
    drop_table :widgets
  end
end

# Call the migration to actually run the sql that builds the table
puts "**** CREATING THE WIDGETS TABLE ****"
CreateWidgets.up

# Setup the class that will access the widgets table
# This class will work regardless of which db is chosen above
class Widget < ActiveRecord::Base
  def to_s
    "Widget ##{id}: #{name.to_s}"
  end
end

# Create a widget
puts "**** CREATING A WIDGET ****"
widget_1 = Widget.create!(:name => "Hello World! (from #{db})")
puts widget_1.to_s

# Output the widgets
puts "**** FIND WIDGETS ****"
Widget.all.each{ |widget| puts widget.to_s }