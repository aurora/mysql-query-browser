
// This file contains common TUT test cases for myx_database_model.c
//
//

//----------------------------------------------------------------------------------------------------------------------

#include "test.h"
#include "myx_public_interface.h"
#include "myx_sql_parser_public_interface.h"
#include "myx_library.h"
#include <fstream>

// Private test data.
BEGIN_TEST_DATA_CLASS(module4_database_model_test)
protected:
  Test_connection* connection;
END_TEST_DATA_CLASS

//----------------------------------------------------------------------------------------------------------------------

TEST_MODULE(module4_database_model_test, "Common test suite, base library");

//----------------------------------------------------------------------------------------------------------------------

TEST_FUNCTION(5)
{
  connection= test_group_singleton.get_connection();
  ensure("Server connection", connection != NULL);
  
  ensure("Sakila test db exists", mysql_select_db(connection->get_mysql(), "sakila") == 0);
}                                                                           

//----------------------------------------------------------------------------------------------------------------------

const char* trigger_test_data= "CREATE DEFINER = `root`@`%` TRIGGER `ins_film` AFTER INSERT ON `film` "
  "FOR EACH ROW BEGIN\n    INSERT INTO film_text (film_id, title, description)\n        "
  "VALUES (new.film_id, new.title, new.description);\n  END";

TEST_FUNCTION(10)
{
  MYX_DBM_TRIGGER_DATA* trigger_data;
  
  trigger_data= myx_dbm_get_trigger_data(connection->get_mysql(), "def", "blah", "payment_date", '`');
  ensure("Getting trigger data from unknown schema", trigger_data == NULL);
  
  trigger_data= myx_dbm_get_trigger_data(connection->get_mysql(), "def", "sakila", "paymentdate", '`');
  ensure("Getting trigger data from unknown name", trigger_data == NULL);
  
  trigger_data= myx_dbm_get_trigger_data(connection->get_mysql(), "def", "sakila", "ins_film", '`');
  ensure("Getting trigger data from valid name", trigger_data != NULL);
  ensure("Validating trigger data", strcmp(trigger_data->catalog, "def") == 0);
  ensure("Validating trigger data", strcmp(trigger_data->schema, "sakila") == 0);
  ensure("Validating trigger data", strcmp(trigger_data->name, "ins_film") == 0);
  ensure_equals("Validating trigger data", std::string(trigger_data->definition), std::string(trigger_test_data));
  myx_dbm_free_trigger_data(trigger_data);
}

//----------------------------------------------------------------------------------------------------------------------

const char* sql_test_data1 = "CREATE DATABASE `sakila` /*!40100 DEFAULT CHARACTER SET latin1 */";
const char* sql_test_data2 = "CREATE TABLE  `sakila`.`country` (\n  `country_id` smallint(5) unsigned NOT NULL "
  "AUTO_INCREMENT,\n  `country` varchar(50) NOT NULL,\n  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP "
  "ON UPDATE CURRENT_TIMESTAMP,\n  PRIMARY KEY (`country_id`)\n) ENGINE=InnoDB DEFAULT CHARSET=utf8";
const char* sql_test_data3 = "CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY INVOKER VIEW  `sakila`.`"
  "actor_info` AS select `a`.`actor_id` AS `actor_id`,`a`.`first_name` AS `first_name`,`a`.`last_name` AS `last_name`,"
  "group_concat(distinct concat(`c`.`name`,_utf8': ',(select group_concat(`f`.`title` order by `f`.`title` "
  "ASC separator ', ') AS `GROUP_CONCAT(f.title ORDER BY f.title SEPARATOR ', ')` from ((`film` `f` join "
  "`film_category` `fc` on((`f`.`film_id` = `fc`.`film_id`))) join `film_actor` `fa` "
  "on((`f`.`film_id` = `fa`.`film_id`))) where ((`fc`.`category_id` = `c`.`category_id`) and (`fa`.`actor_id` = "
  "`a`.`actor_id`)))) order by `c`.`name` ASC separator '; ') AS `film_info` from (((`actor` `a` left "
  "join `film_actor` `fa` on((`a`.`actor_id` = `fa`.`actor_id`))) left join `film_category` "
  "`fc` on((`fa`.`film_id` = `fc`.`film_id`))) left join `category` `c` on((`fc`.`category_id` = `c`.`"
  "category_id`))) group by `a`.`actor_id`,`a`.`first_name`,`a`.`last_name`";
const char* sql_test_data4 = "CREATE DEFINER=`root`@`%` PROCEDURE  `sakila`.`film_in_stock`(IN p_film_id INT, "
  "IN p_store_id INT, OUT p_film_count INT)\n    READS SQL DATA\nBEGIN\n     SELECT inventory_id\n     "
  "FROM inventory\n     WHERE film_id = p_film_id\n     AND store_id = p_store_id\n     AND inventory_in_stock("
  "inventory_id);\n     SELECT FOUND_ROWS() INTO p_film_count;\nEND";
const char* sql_test_data5 = "CREATE DEFINER=`root`@`%` FUNCTION  `sakila`.`get_customer_balance`(p_customer_id INT, "
  "p_effective_date DATETIME) RETURNS decimal(5,2)\n    READS SQL DATA\n    DETERMINISTIC\nBEGIN\n       \n       "
  "\n       \n       \n       \n       \n  DECLARE v_rentfees DECIMAL(5,2); \n  DECLARE v_overfees INTEGER;      "
  "\n  DECLARE v_payments DECIMAL(5,2); \n  SELECT IFNULL(SUM(film.rental_rate),0) INTO v_rentfees\n    FROM film, "
  "inventory, rental\n    WHERE film.film_id = inventory.film_id\n      AND inventory.inventory_id = "
  "rental.inventory_id\n      AND rental.rental_date <= p_effective_date\n      AND rental.customer_id = "
  "p_customer_id;\n  SELECT IFNULL(SUM(IF((TO_DAYS(rental.return_date) - TO_DAYS(rental.rental_date)) > "
  "film.rental_duration,\n        ((TO_DAYS(rental.return_date) - TO_DAYS(rental.rental_date)) - "
  "film.rental_duration),0)),0) INTO v_overfees\n    FROM rental, inventory, film\n    WHERE film.film_id = "
  "inventory.film_id\n      AND inventory.inventory_id = rental.inventory_id\n      AND rental.rental_date <= "
  "p_effective_date\n      AND rental.customer_id = p_customer_id;\n  SELECT IFNULL(SUM(payment.amount),0) INTO "
  "v_payments\n    FROM payment\n    WHERE payment.payment_date <= p_effective_date\n    AND payment.customer_id = "
  "p_customer_id;\n  RETURN v_rentfees + v_overfees - v_payments;\nEND";
const char* sql_test_data6 = "CREATE DEFINER = `root`@`%` TRIGGER  `sakila`.`upd_film` AFTER UPDATE ON `film` FOR "
  "EACH ROW BEGIN\n    IF (old.title != new.title) or (old.description != new.description)\n    THEN\n        "
  "UPDATE film_text\n            SET title=new.title,\n                description=new.description,\n                "
  "film_id=new.film_id\n        WHERE film_id=old.film_id;\n    END IF;\n  END";

TEST_FUNCTION(15)
{
  char* sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "BLAH", MYX_DBM_OT_SCHEMA, 1, '`');
  ensure("Getting database creation sql", strcmp(sql, sql_test_data1) == 0);
  g_free(sql);

  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "BLAH", MYX_DBM_OT_TABLE, 1, '`');
  ensure("Getting creation sql for invalid table", sql == NULL);
  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "country", MYX_DBM_OT_TABLE, 1, '`');
  ensure("Getting creation sql for valid table", strcmp(sql, sql_test_data2) == 0);
  g_free(sql);

  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "BLAH", MYX_DBM_OT_VIEW, 1, '`');
  ensure("Getting creation sql for invalid view", sql == NULL);
  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "actor_info", MYX_DBM_OT_VIEW, 1, '`');

  ensure_equals("Getting creation sql for valid view", std::string(sql), std::string(sql_test_data3));
  g_free(sql);

  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "BLAH", MYX_DBM_OT_PROCEDURE, 1, '`');
  ensure("Getting creation sql for invalid stored procedure", sql == NULL);
  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "film_in_stock", MYX_DBM_OT_PROCEDURE, 1, '`');
  ensure("Getting creation sql for valid stored procedure", strcmp(sql, sql_test_data4) == 0);
  g_free(sql);

  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "BLAH", MYX_DBM_OT_FUNCTION, 1, '`');
  ensure("Getting creation sql for invalid stored function", sql == NULL);
  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "get_customer_balance", MYX_DBM_OT_FUNCTION, 1, '`');
  ensure("Getting creation sql for valid stored function", strcmp(sql, sql_test_data5) == 0);
  g_free(sql);

  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "BLAH", MYX_DBM_OT_TRIGGER, 1, '`');
  ensure("Getting creation sql for invalid trigger", sql == NULL);
  sql= myx_dbm_get_create_sql(connection->get_mysql(), "def", "sakila", "upd_film", MYX_DBM_OT_TRIGGER, 1, '`');
  ensure("Getting creation sql for valid trigger", strcmp(sql, sql_test_data6) == 0);
  g_free(sql);
}

//----------------------------------------------------------------------------------------------------------------------

const char *sql_test_20_data1= "DROP DATABASE IF EXISTS `ma_tests`;";
const char *sql_test_20_data2= "ALTER TABLE `ma_tests`.`dbm_test` ADD COLUMN `default_test` " \
  "VARCHAR(45) NOT NULL DEFAULT 'test' AFTER `test2`;" _br;

TEST_FUNCTION(20)
{
  Auto_release auto_release;

  MYX_LIB_ERROR error_code= MYX_NO_ERROR;

  // load datatypes from XML file
  std::string filename= test_group_singleton.get_full_filename("mysqlx_dbm_datatypes.xml");
  MYX_DBM_DATATYPES *datatypes= auto_release.add(myx_datatype_load(filename.c_str(), &error_code));

  std::stringstream msg;
  msg << "Loading datatypes (" << error_code << ")";
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);
  ensure("Datatypes valid", datatypes);

  // Create test schema and table
  filename= test_group_singleton.get_full_filename("test_20_1.sql");

  std::ifstream is(filename.c_str());

  connection->multi_query(is);

  // make sure the test database is removed after the tests
  auto_release.add_sql(connection, sql_test_20_data1);

  // Retrieve table data
  MYX_DBM_TABLE_DATA *tbl_data= auto_release.add(myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes,
    NULL, "ma_tests", "dbm_test", &error_code));

  msg.str("");
  msg << "Fetching ma_tests.dbm_test table data (" << error_code << ")";
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);
  ensure("Table data valid", tbl_data);

  // add new column
  MYX_DBM_COLUMN_DATA *col;

  tbl_data->columns_num++;
  tbl_data->columns= (MYX_DBM_COLUMN_DATA *) g_realloc(tbl_data->columns,
    sizeof(MYX_DBM_COLUMN_DATA) * tbl_data->columns_num);
  col= tbl_data->columns + (tbl_data->columns_num - 1);
  memset(col, 0, sizeof(MYX_DBM_COLUMN_DATA));
  col->name= g_strdup("default_test");
  col->datatype_name= g_strdup("VARCHAR");
  col->datatype_params= g_strdup("(45)");
  col->not_null= 1;
  col->default_value= g_strdup("'test'");
  col->datatype_pointer= datatypes->datatypes + 19;

  // get original tbl_data again
  MYX_DBM_TABLE_DATA *existing_tbl_data= auto_release.add(myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes,
    NULL, "ma_tests", "dbm_test", &error_code));
  ensure(msg.str(), error_code == MYX_NO_ERROR);

  // get server version
  MYX_DBM_SERVER_VERSION *version= auto_release.add(myx_dbm_retrieve_server_version(connection->get_mysql()));
  ensure("Could not get server version", version);

  // get diff SQL
  char *diff_sql= auto_release.add_g_free(myx_dbm_get_table_sql_diff(existing_tbl_data, tbl_data, version, &error_code));
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);

  // check diff SQL
  msg.str("");
  msg << "SQL ALTER TABLE string is incorrect." _br <<
    "|" << sql_test_20_data2 << "|" _br _br "|" << diff_sql << "|";
  ensure(msg.str(), strcmp2(sql_test_20_data2, diff_sql) == 0);

  // execute diff SQL
  connection->multi_query(diff_sql);

  // get altered tbl_data again
  existing_tbl_data= auto_release.add(myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes,
    NULL, "ma_tests", "dbm_test", &error_code));
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);

  col->original_name= g_strdup(col->name);

  // get diff SQL
  diff_sql= myx_dbm_get_table_sql_diff(existing_tbl_data, tbl_data, version, &error_code);
  ensure(msg.str(), error_code == MYX_NO_ERROR);

  msg.str("");
  msg << "SQL ALTER TABLE string should be empty." _br << diff_sql;
  ensure(msg.str(), strcmp3(diff_sql, "") == 0);
}

//----------------------------------------------------------------------------------------------------------------------

TEST_FUNCTION(25)
{
  MYX_LIB_ERROR error_code= MYX_NO_ERROR;

  Auto_release ar;
  ar.add_sql(connection, "DROP DATABASE IF EXISTS `ma_tests`;DROP DATABASE IF EXISTS `ma_tests2`;");

  std::string filename= test_group_singleton.get_full_filename("mysqlx_dbm_datatypes.xml");
  MYX_DBM_DATATYPES *datatypes= ar.add(myx_datatype_load(filename.c_str(), &error_code));

  filename= test_group_singleton.get_full_filename("test_25_1.sql");

  std::ifstream is(filename.c_str());
  connection->multi_query(is);

  MYX_DBM_TABLE_DATA *data= ar.add(
    myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes, NULL, "ma_tests", "f", &error_code));

  ensure("Correct number of FKs", data->fks_num == 2);
  ensure("Correct reference to a table in another schema",
    (strcmp2(data->fks[1].reference_schema_name, "ma_tests2") == 0) &&
    (strcmp2(data->fks[1].reference_table_name, "r2") == 0));
}

//----------------------------------------------------------------------------------------------------------------------

const char *sql_test_27_data1= "drop schema jagodinac";
const char *sql_test_27_data2= "drop schema finansijsko";

TEST_FUNCTION(27)
{
  MYX_LIB_ERROR error_code= MYX_NO_ERROR;

  Auto_release auto_release;

  // Make sure the test database is removed after the tests.
  auto_release.add_sql(connection, sql_test_27_data1);
  auto_release.add_sql(connection, sql_test_27_data2);

  // Load datatypes from XML file. They are needed for the table data retrieval.
  std::string filename= test_group_singleton.get_full_filename("mysqlx_dbm_datatypes.xml");
  MYX_DBM_DATATYPES *datatypes= auto_release.add(myx_datatype_load(filename.c_str(), &error_code));

  std::stringstream msg;
  msg << "Loading datatypes (" << error_code << ")";
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);
  ensure("Datatypes valid", datatypes);

  filename= test_group_singleton.get_full_filename("test_25_2.sql");

  std::ifstream is(filename.c_str());
  connection->multi_query(is);

  MYX_DBM_TABLE_DATA *data= auto_release.add(
    myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes, NULL, "jagodinac", "stavke_na_racunima", &error_code));

  ensure("Check number of foreign keys", data->fks_num == 3);
  ensure("Correct reference to a table in another schema",
    (strcmp2(data->fks[2].reference_schema_name, "finansijsko") == 0) &&
    (strcmp2(data->fks[2].reference_table_name, "magacini") == 0));
}

//----------------------------------------------------------------------------------------------------------------------

TEST_FUNCTION(30)
{
  Auto_release auto_release;

  MYX_LIB_ERROR error_code= MYX_NO_ERROR;

  // load datatypes from XML file
  std::string filename= test_group_singleton.get_full_filename("mysqlx_dbm_datatypes.xml");
  MYX_DBM_DATATYPES *datatypes= auto_release.add(myx_datatype_load(filename.c_str(), &error_code));

  std::stringstream msg;
  msg << "Loading datatypes (" << error_code << ")";
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);
  ensure("Datatypes valid", datatypes);

  // Create test schema and table
  filename= test_group_singleton.get_full_filename("test_21_1.sql");

  std::ifstream is(filename.c_str());

  connection->multi_query(is);

  // make sure the test database is removed after the tests
  auto_release.add_sql(connection, sql_test_20_data1);

  // Retrieve table data
  MYX_DBM_TABLE_DATA *tbl_data= auto_release.add(myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes,
    NULL, "ma_tests", "ba", &error_code));

  msg.str("");
  msg << "Fetching ma_tests.ba table data (" << error_code << ")";
  ensure(msg.str(), error_code == MYX_NO_ERROR);
  ensure("Table data valid", tbl_data);
  ensure("Table must have two FKs", tbl_data->fks_num == 2);

  // change FKs
  MYX_DBM_FK_DATA *fk1= tbl_data->fks, *fk2= tbl_data->fks + 1;
  fk1->on_delete= MYX_DBM_FA_RESTRICT;
  fk2->on_delete= MYX_DBM_FA_RESTRICT;


  // get original tbl_data again
  MYX_DBM_TABLE_DATA *existing_tbl_data= auto_release.add(myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes,
    NULL, "ma_tests", "ba", &error_code));
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);

  // get server version
  MYX_DBM_SERVER_VERSION *version= auto_release.add(myx_dbm_retrieve_server_version(connection->get_mysql()));
  ensure("Could not get server version", version);

  // get diff SQL
  auto_release.add_g_free(myx_dbm_get_table_sql_diff(existing_tbl_data, tbl_data, version, &error_code));
  ensure_equals(msg.str(), error_code, MYX_NO_ERROR);
}

//----------------------------------------------------------------------------------------------------------------------

const char* test_35_data1= "ENGINE = InnoDB\r\nAUTO_INCREMENT = 500\r\nPACK_KEYS = 1\r\nRAID_TYPE = STRIPED\r\n"
  "ROW_FORMAT = REDUNDANT";
const char* test_35_data2= "TYPE = InnoDB\r\nAUTO_INCREMENT = 500\r\nPACK_KEYS = 1\r\nRAID_TYPE = STRIPED\r\n"
  "ROW_FORMAT = REDUNDANT";
const char* test_35_data3= "ENGINE = InnoDB\r\nAUTO_INCREMENT = 500\r\nPASSWORD = 'root'\r\nDELAY_KEY_WRITE = 1\r\n"
  "CHARACTER SET latin1 COLLATE latin1_german1_ci\r\nCOMMENT = 'make it good!'\r\nPACK_KEYS = 1\r\nRAID_TYPE = STRIPED"
  "\r\nROW_FORMAT = REDUNDANT";

TEST_FUNCTION(35)
{
  MYX_DBM_TABLE_DATA data;
  MYX_DBM_SERVER_VERSION version;
  Auto_release auto_release;

  version.major_version= 5;
  version.minor_version= 0;

  data.name= "test_table";
  data.original_name= "original_table";
  data.schema= "home";
  data.catalog= NULL;
  data.create_table_stmt= NULL;
  data.table_engine= MYX_DBM_TE_INNODB;
  data.next_auto_inc= "500";
  data.password= NULL;
  data.delay_key_write= 0;
  data.charset= NULL;
  data.collation= NULL;
  data.comment= NULL;
  data.merge_union= NULL;
  data.merge_insert= MYX_DBM_TMI_FIRST;
  data.table_data_dir= NULL;
  data.table_index_dir= NULL;
  data.pack_keys= MYX_DBM_TPK_ALL;
  data.raid_type= MYX_DBM_TRT_STRIPED;
  data.raid_chunks= NULL;
  data.raid_chunk_size= NULL;
  data.checksum= NULL;
  data.row_format= MYX_DBM_TRF_REDUNDANT;
  data.avg_row_length= NULL;
  data.min_rows= NULL;
  data.max_rows= NULL;
  data.fks_num= NULL;
  data.fks= NULL;
  data.columns_num= NULL;
  data.columns= NULL;
  data.indices_num= NULL;
  data.indices= NULL;
  data.federated_connection= NULL;

  char* code= auto_release.add_g_free(myx_dbm_get_sql_option_create_code(&data, &version));
  ensure("Validating sql option create code", strcmp(code, test_35_data1) == 0);

  version.major_version= 4;
  code= auto_release.add_g_free(myx_dbm_get_sql_option_create_code(&data, &version));
  ensure("Validating sql option create code", strcmp(code, test_35_data2) == 0);

  data.password= "root";
  data.delay_key_write= 1;
  data.charset= "latin1";
  data.collation= "latin1_german1_ci";
  data.comment= "make it good!";

  version.major_version= 4;
  version.minor_version= 111;
  code= auto_release.add_g_free(myx_dbm_get_sql_option_create_code(&data, &version));
  ensure("Validating sql option create code", strcmp(code, test_35_data3) == 0);

}

//----------------------------------------------------------------------------------------------------------------------

/*
  test for bug #19666
*/

TEST_FUNCTION(40)
{
  Auto_release ar;

  MYX_LIB_ERROR error_code= MYX_NO_ERROR;

  connection->query("DROP TABLE IF EXISTS `test`.`test19666`;");
  connection->query("CREATE TABLE `test`.`test19666` (id INT PRIMARY KEY) CHECKSUM=1");
  ar.add_sql(connection, "DROP TABLE IF EXISTS `test`.`test19666`");

  std::string filename= test_group_singleton.get_full_filename("mysqlx_dbm_datatypes.xml");
  MYX_DBM_DATATYPES *datatypes= ar.add(myx_datatype_load(filename.c_str(), &error_code));
  MYX_DBM_TABLE_DATA *tbl_data= ar.add(myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes,
    NULL, "test", "test19666", &error_code));

  ensure("Checksum is not properly parsed", tbl_data->checksum == 1);
}

//----------------------------------------------------------------------------------------------------------------------

/*
  test for bug #13395
*/

extern "C" char * myx_dbm_get_sql_fk_create_code(MYX_DBM_FK_DATA *fk, MYX_DBM_SERVER_VERSION *version);

TEST_FUNCTION(45)
{
  Auto_release ar;

  MYX_DBM_SERVER_VERSION ver;
  ver.major_version= 5;
  ver.minor_version= 0;

  MYX_NAME_VALUE_PAIR fks[2];
  fks[0].name= "c1";
  fks[0].value= "r1";
  fks[1].name= "";
  fks[1].value= "";

  MYX_DBM_FK_DATA fkdata;
  fkdata.name= "fk1";
  fkdata.original_name= "fk1";
  fkdata.reference_schema_name= "";
  fkdata.reference_table_name= "reftable";
  fkdata.column_mapping_num= 2;
  fkdata.on_delete= MYX_DBM_FA_CASCADE;
  fkdata.on_update= MYX_DBM_FA_CASCADE;
  fkdata.column_mapping= fks;


  char *sql;
  ar.add_g_free(sql= myx_dbm_get_sql_fk_create_code(&fkdata, &ver));

  ensure("Incorrect FK SQL generated", strcmp(sql,
    "CONSTRAINT `fk1` FOREIGN KEY `fk1` (`c1`)\r\n    REFERENCES `reftable` (`r1`)\r\n    ON DELETE CASCADE\r\n    ON UPDATE CASCADE") == 0);
}

//----------------------------------------------------------------------------------------------------------------------

/*
  test for bug #23081
*/

TEST_FUNCTION(50)
{
  MYX_LIB_ERROR error_code= MYX_NO_ERROR;

  Auto_release ar;

  connection->query("DROP TABLE IF EXISTS `test`.`test23081`;");
  connection->query("CREATE TABLE `test`.`test23081` (id INT NOT NULL, UNIQUE KEY `Index_1` (`id`))");
  ar.add_sql(connection, "DROP TABLE IF EXISTS `test`.`test23081`");

  // load datatypes from XML file
  std::string filename= test_group_singleton.get_full_filename("mysqlx_dbm_datatypes.xml");
  MYX_DBM_DATATYPES *datatypes= ar.add(myx_datatype_load(filename.c_str(), &error_code));

  MYX_DBM_TABLE_DATA *tbl_data= ar.add(myx_dbm_retrieve_table_data(connection->get_mysql(), datatypes,
    NULL, "test", "test23081", &error_code));

  ensure("False PK reverse-engineered", tbl_data->columns[0].primary_key == 0);
}

//----------------------------------------------------------------------------------------------------------------------

/*
  parser test
*/

TEST_FUNCTION(55)
{
  MYX_LIB_ERROR error_code= MYX_NO_ERROR;

  //static const char *sql= "CREATE TABLE \"pmtask\" (\n  \"ID\" bigint(20) NOT NULL,\n  \"tasksCode\" varchar(255) DEFAULT NULL,\n  \"description\" varchar(255) DEFAULT NULL,\n  \"note\" varchar(255) DEFAULT NULL,\n  \"spec\" varchar(255) DEFAULT NULL,\n  PRIMARY KEY (\"ID\")\n) ENGINE=InnoDB DEFAULT CHARSET=utf8";
  static const char *sql= "CREATE TABLE pmtask (\n  ID bigint(20) NOT NULL,\n  tasksCode varchar(255) DEFAULT NULL,\n  description varchar(255) DEFAULT NULL,\n  note varchar(255) DEFAULT NULL,\n  spec varchar(255) DEFAULT NULL,\n  PRIMARY KEY (ID)\n) ENGINE=InnoDB DEFAULT CHARSET=utf8";

  void *parser_tree= NULL;
  myx_set_parser_source(sql);
  myx_parse();

  parser_tree= myx_get_parser_tree();

  ensure("Parser failed", parser_tree != NULL);
}

//----------------------------------------------------------------------------------------------------------------------

END_TESTS;

//----------------------------------------------------------------------------------------------------------------------

