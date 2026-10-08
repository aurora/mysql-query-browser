
// This file contains common TUT test cases for myx_query.cpp
//
//

//----------------------------------------------------------------------------------------------------------------------

#include "test.h"
#include "myx_query.h"

// Private test data.
BEGIN_TEST_DATA_CLASS(module5_query_test)
protected:
  Test_connection* connection;
END_TEST_DATA_CLASS

//----------------------------------------------------------------------------------------------------------------------

TEST_MODULE(module5_query_test, "Common test suite, base library");

//----------------------------------------------------------------------------------------------------------------------

TEST_FUNCTION(5)
{
  connection= test_group_singleton.get_connection();
  ensure("Valid server connection", connection != NULL);
}

//----------------------------------------------------------------------------------------------------------------------

TEST_FUNCTION(10)
{
  Query* query = new Query();
  query->analyze(connection->get_mysql(), "select * from table1");
  ensure("Analyze query", !query_is_join(query));
  delete query;

  query = new Query();
  query->analyze(connection->get_mysql(), "select cd.titel, f.name from cd join  (verleihtabelle t join freunde f on"
    "t.freundenr=f.nummer) on cd.nummer=t.cdnummer;");
  ensure("Analyze query", query_is_join(query));
  delete query;
}

//----------------------------------------------------------------------------------------------------------------------

END_TESTS;

//----------------------------------------------------------------------------------------------------------------------

