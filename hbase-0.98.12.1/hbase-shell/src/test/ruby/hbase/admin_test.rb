#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'shell'
require 'shell/formatter'
require 'hbase'
require 'hbase/hbase'
require 'hbase/table'

include HBaseConstants

module Hbase
  class AdminHelpersTest < Test::Unit::TestCase
    include TestHelpers

    def setup
      setup_hbase
      # Create test table if it does not exist
      @test_name = "hbase_shell_tests_table"
      create_test_table(@test_name)
    end

    define_test "exists? should return true when a table exists" do
      assert(admin.exists?('hbase:meta'))
    end

    define_test "exists? should return false when a table exists" do
      assert(!admin.exists?('NOT.EXISTS'))
    end

    define_test "enabled? should return true for enabled tables" do
      admin.enable(@test_name)
      assert(admin.enabled?(@test_name))
    end

    define_test "enabled? should return false for disabled tables" do
      admin.disable(@test_name)
      assert(!admin.enabled?(@test_name))
    end
  end

    # Simple administration methods tests
  class AdminMethodsTest < Test::Unit::TestCase
    include TestHelpers

    def setup
      setup_hbase
      # Create test table if it does not exist
      @test_name = "hbase_shell_tests_table"
      create_test_table(@test_name)

      # Create table test table name
      @create_test_name = 'hbase_create_table_test_table'
    end

    define_test "list should return a list of tables" do
      assert(admin.list.member?(@test_name))
    end

    define_test "list should not return meta tables" do
      assert(!admin.list.member?('hbase:meta'))
    end

    define_test "list_namespace_tables for the system namespace should return a list of tables" do
      assert(admin.list_namespace_tables('hbase').count > 0)
    end

    define_test "list_namespace_tables for the default namespace should return a list of tables" do
      assert(admin.list_namespace_tables('default').count > 0)
    end

    #-------------------------------------------------------------------------------

    define_test "flush should work" do
      admin.flush('hbase:meta')
    end

    #-------------------------------------------------------------------------------

    define_test "compact should work" do
      admin.compact('hbase:meta')
    end

    #-------------------------------------------------------------------------------

    define_test "major_compact should work" do
      admin.major_compact('hbase:meta')
    end

    #-------------------------------------------------------------------------------

    define_test "split should work" do
      admin.split('hbase:meta', nil)
    end

    #-------------------------------------------------------------------------------

    define_test "drop should fail on non-existent tables" do
      assert_raise(ArgumentError) do
        admin.drop('NOT.EXISTS')
      end
    end

    define_test "drop should fail on enabled tables" do
      assert_raise(ArgumentError) do
        admin.drop(@test_name)
      end
    end

    define_test "drop should drop tables" do
      admin.disable(@test_name)
      admin.drop(@test_name)
      assert(!admin.exists?(@test_name))
    end

    #-------------------------------------------------------------------------------

    define_test "zk_dump should work" do
      assert_not_nil(admin.zk_dump)
    end

    #-------------------------------------------------------------------------------

    define_test "create should fail with non-string table names" do
      assert_raise(ArgumentError) do
        admin.create(123, 'xxx')
      end
    end

    define_test "create should fail with non-string/non-hash column args" do
      assert_raise(ArgumentError) do
        admin.create(@create_test_name, 123)
      end
    end

    define_test "create should fail without columns" do
      drop_test_table(@create_test_name)
      assert_raise(ArgumentError) do
        admin.create(@create_test_name)
      end
    end
    
    define_test "create should fail without columns when called with options" do
      drop_test_table(@create_test_name)
      assert_raise(ArgumentError) do
        admin.create(@create_test_name, { OWNER => 'a' })
      end
    end

    define_test "create should work with string column args" do
      drop_test_table(@create_test_name)
      admin.create(@create_test_name, 'a', 'b')
      assert_equal(['a:', 'b:'], table(@create_test_name).get_all_columns.sort)
     end

    define_test "create should work with hash column args" do
      drop_test_table(@create_test_name)
      admin.create(@create_test_name, { NAME => 'a'}, { NAME => 'b'})
      assert_equal(['a:', 'b:'], table(@create_test_name).get_all_columns.sort)
    end
    
    define_test "create should be able to set table options" do
      drop_test_table(@create_test_name)
      admin.create(@create_test_name, 'a', 'b', 'MAX_FILESIZE' => 12345678, OWNER => '987654321')
      assert_equal(['a:', 'b:'], table(@create_test_name).get_all_columns.sort)
      assert_match(/12345678/, admin.describe(@create_test_name))
      assert_match(/987654321/, admin.describe(@create_test_name))
    end
        
    define_test "create should ignore table_att" do
      drop_test_table(@create_test_name)
      admin.create(@create_test_name, 'a', 'b', METHOD => 'table_att', OWNER => '987654321')
      assert_equal(['a:', 'b:'], table(@create_test_name).get_all_columns.sort)
      assert_match(/987654321/, admin.describe(@create_test_name))
    end
    
    define_test "create should work with SPLITALGO" do
      drop_test_table(@create_test_name)
      admin.create(@create_test_name, 'a', 'b', {NUMREGIONS => 10, SPLITALGO => 'HexStringSplit'})
      assert_equal(['a:', 'b:'], table(@create_test_name).get_all_columns.sort)
    end

    #-------------------------------------------------------------------------------

    define_test "describe should fail for non-existent tables" do
      assert_raise(NativeException) do
        admin.describe('.NOT.EXISTS.')
      end
    end

    define_test "describe should return a description" do
      assert_not_nil admin.describe(@test_name)
    end

    #-------------------------------------------------------------------------------

    define_test "truncate should empty a table" do
      table(@test_name).put(1, "x:a", 1)
      table(@test_name).put(2, "x:a", 2)
      assert_equal(2, table(@test_name)._count_internal)
      # This is hacky.  Need to get the configuration into admin instance
      admin.truncate(@test_name, $TEST_CLUSTER.getConfiguration)
      assert_equal(0, table(@test_name)._count_internal)
    end

    define_test "truncate should yield log records" do
      logs = []
      admin.truncate(@test_name, $TEST_CLUSTER.getConfiguration) do |log|
        assert_kind_of(String, log)
        logs << log
      end
      assert(!logs.empty?)
    end
  end

 # Simple administration methods tests
  class AdminAlterTableTest < Test::Unit::TestCase
    include TestHelpers

    def setup
      setup_hbase
      # Create test table if it does not exist
      @test_name = "hbase_shell_tests_table"
      drop_test_table(@test_name)
      create_test_table(@test_name)
    end

    #-------------------------------------------------------------------------------

    define_test "alter should fail with non-string table names" do
      assert_raise(ArgumentError) do
        admin.alter(123, true, METHOD => 'delete', NAME => 'y')
      end
    end

    define_test "alter should fail with non-existing tables" do
      assert_raise(ArgumentError) do
        admin.alter('NOT.EXISTS', true, METHOD => 'delete', NAME => 'y')
      end
    end

    define_test "alter should not fail with enabled tables" do
      admin.enable(@test_name)
      admin.alter(@test_name, true, METHOD => 'delete', NAME => 'y')
    end

    define_test "alter should be able to delete column families" do
      assert_equal(['x:', 'y:'], table(@test_name).get_all_columns.sort)
      admin.alter(@test_name, true, METHOD => 'delete', NAME => 'y')
      admin.enable(@test_name)
      assert_equal(['x:'], table(@test_name).get_all_columns.sort)
    end

    define_test "alter should be able to add column families" do
      assert_equal(['x:', 'y:'], table(@test_name).get_all_columns.sort)
      admin.alter(@test_name, true, NAME => 'z')
      admin.enable(@test_name)
      assert_equal(['x:', 'y:', 'z:'], table(@test_name).get_all_columns.sort)
    end

    define_test "alter should be able to add column families (name-only alter spec)" do
      assert_equal(['x:', 'y:'], table(@test_name).get_all_columns.sort)
      admin.alter(@test_name, true, 'z')
      admin.enable(@test_name)
      assert_equal(['x:', 'y:', 'z:'], table(@test_name).get_all_columns.sort)
    end

    define_test "alter should support more than one alteration in one call" do
      assert_equal(['x:', 'y:'], table(@test_name).get_all_columns.sort)
      admin.alter(@test_name, true, { NAME => 'z' }, { METHOD => 'delete', NAME => 'y' }, 'MAX_FILESIZE' => 12345678)
      admin.enable(@test_name)
      assert_equal(['x:', 'z:'], table(@test_name).get_all_columns.sort)
      assert_match(/12345678/, admin.describe(@test_name))
    end

    define_test 'alter should support shortcut DELETE alter specs' do
      assert_equal(['x:', 'y:'], table(@test_name).get_all_columns.sort)
      admin.alter(@test_name, true, 'delete' => 'y')
      assert_equal(['x:'], table(@test_name).get_all_columns.sort)
    end

    define_test "alter should be able to change table options" do
      admin.alter(@test_name, true, METHOD => 'table_att', 'MAX_FILESIZE' => 12345678)
      assert_match(/12345678/, admin.describe(@test_name))
    end

    define_test "alter should be able to change table options w/o table_att" do
      admin.alter(@test_name, true, 'MAX_FILESIZE' => 12345678)
      assert_match(/12345678/, admin.describe(@test_name))
    end
    
    define_test "alter should be able to change coprocessor attributes" do
      drop_test_table(@test_name)
      create_test_table(@test_name)

      cp_key = "coprocessor"
      class_name = "org.apache.hadoop.hbase.coprocessor.SimpleRegionObserver"

      cp_value = "|" + class_name + "|12|arg1=1,arg2=2"

      # eval() is used to convert a string to regex
      assert_no_match(eval("/" + class_name + "/"), admin.describe(@test_name))
      assert_no_match(eval("/" + cp_key + "/"), admin.describe(@test_name))
      admin.alter(@test_name, true, 'METHOD' => 'table_att', cp_key => cp_value)
      assert_match(eval("/" + class_name + "/"), admin.describe(@test_name))
      assert_match(eval("/" + cp_key + "\\$(\\d+)/"), admin.describe(@test_name))
    end

    define_test "alter should be able to remove a table attribute" do
      drop_test_table(@test_name)
      create_test_table(@test_name)

      key = "MAX_FILESIZE"
      admin.alter(@test_name, true, 'METHOD' => 'table_att', key => 12345678)

      # eval() is used to convert a string to regex
      assert_match(eval("/" + key + "/"), admin.describe(@test_name))

      admin.alter(@test_name, true, 'METHOD' => 'table_att_unset', 'NAME' => key)
      assert_no_match(eval("/" + key + "/"), admin.describe(@test_name))
    end

    define_test "get_table should get a real table" do
      drop_test_table(@test_name)
      create_test_table(@test_name)

      table = table(@test_name)
      assert_not_equal(nil, table)
    end

    define_test "Get replication status" do
      replication_status("replication", "both")
    end

    define_test "Get replication source metrics information" do
      replication_status("replication", "source")
    end

    define_test "Get replication sink metrics information" do
      replication_status("replication", "sink")
    end
  end
end
