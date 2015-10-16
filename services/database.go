package services

import (
	"fmt"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

/**
 * Global variables
 */

var db *sqlx.DB

func InitDBConnection(role, password, database, ip string) {
	postgresUrl := fmt.Sprintf("user=%s password=%s dbname=%s sslmode=disable host=%s", role, password, database, ip)
	db = sqlx.MustConnect("postgres", postgresUrl)
}
