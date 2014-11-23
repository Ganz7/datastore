#include <cstdio>
#include <string>
#include <vector>

#include "rocksdb/db.h"
#include "rocksdb/slice.h"
#include "rocksdb/options.h"

using namespace rocksdb;

std::string kDBPath = "/tmp/datastore_test";

int main() {
	
	/* Destroys the DB */
	DestroyDB(kDBPath, Options());

	return 0;
}
