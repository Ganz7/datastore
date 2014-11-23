#include <cstdio>
#include <string>
#include <vector>

#include "rocksdb/db.h"
#include "rocksdb/slice.h"
#include "rocksdb/options.h"

using namespace rocksdb;

std::string kDBPath = "/tmp/datastore_test";

int main() {
	// open db
	DB* db;
  	Status s;

	// open DB with the column families
  	std::vector<ColumnFamilyDescriptor> column_families;
  	// have to open default column familiy
  	column_families.push_back(ColumnFamilyDescriptor(
      	kDefaultColumnFamilyName, ColumnFamilyOptions()));
  	// open the word_list and sentence_list column families
  	column_families.push_back(ColumnFamilyDescriptor(
      		"word_list", ColumnFamilyOptions()));
  	column_families.push_back(ColumnFamilyDescriptor(
      		"sentence_list", ColumnFamilyOptions()));
  	std::vector<ColumnFamilyHandle*> handles;
  	s = DB::Open(DBOptions(), kDBPath, column_families, &handles, &db);
  	assert(s.ok());

	// write the test values into the column families
 	std::string some_random_pointer = "x12345";
	s = db->Put(WriteOptions(), handles[1], Slice("hello"), Slice(some_random_pointer));
  	assert(s.ok());
  	s = db->Put(WriteOptions(), handles[2], Slice(some_random_pointer), Slice("hello world"));

	//Retreive pointer from word_list
	std::string received_pointer;
  	s = db->Get(ReadOptions(), handles[1], Slice("hello"), &received_pointer);
  	assert(s.ok());
  	assert(some_random_pointer == received_pointer);
	
	//Retreive sentence using received_pointer
	std::string sentence;
  	s = db->Get(ReadOptions(), handles[2], Slice(received_pointer), &sentence);
 	assert(s.ok());
  	assert(sentence == "hello world");

	// close db
  	for (auto handle : handles) {
    		delete handle;
  	}	
  	delete db;

  	return 0;

}
