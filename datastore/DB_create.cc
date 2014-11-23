#include <cstdio>
#include <string>
#include <iostream>

#include "rocksdb/db.h"
#include "rocksdb/slice.h"
#include "rocksdb/options.h"

using namespace rocksdb;

std::string kDBPath = "/tmp/datastore_test";

int main() {
  	DB* db;
  	Options options;
	// Optimize RocksDB. This is the easiest way to get RocksDB to perform well
  	options.IncreaseParallelism();
  	options.OptimizeLevelStyleCompaction();
  	// create the DB if it's not already present
	options.create_if_missing = true;

	// open DB
	Status s = DB::Open(options, kDBPath, &db);
	assert(s.ok());
	
	// create word_list column family
  	ColumnFamilyHandle* cf1;
  	s = db->CreateColumnFamily(ColumnFamilyOptions(), "word_list", &cf1);
  	assert(s.ok());

  	// create sentence_list column family
  	ColumnFamilyHandle* cf2;
  	s = db->CreateColumnFamily(ColumnFamilyOptions(), "sentence_list", &cf2);
  	assert(s.ok());

	//Delete DB and Column family Objects
	delete cf1;
	delete cf2;
	delete db;
}
