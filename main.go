package main

import (
	"flag"
	"fmt"
	"log"
	"runtime"
	"sync"

	"github.com/gin-gonic/contrib/gzip"
	"github.com/gin-gonic/gin"
	"github.com/glacjay/goini"
	"github.com/vitaminwater/parsemap/services"
)

/**
 * Config ini
 */

type MustDict struct {
	ini.Dict
}

var config MustDict

func (dict MustDict) mustGetString(section, key string) string {
	value, ok := dict.GetString(section, key)
	if ok == false {
		log.Fatalf("Missing field %s in section %s", key, section)
	}
	return value
}

func httpListenString() string {
	httpIp := config.mustGetString("parsemap", "ip")
	httpPort := config.mustGetString("parsemap", "port")
	listen := fmt.Sprintf("%s:%s", httpIp, httpPort)
	return listen
}

func httpsListenString() string {
	httpsIp := config.mustGetString("parsemap", "ssl_ip")
	httpsPort := config.mustGetString("parsemap", "ssl_port")
	listen := fmt.Sprintf("%s:%s", httpsIp, httpsPort)
	return listen
}

func init() {
	var configFile string
	flag.StringVar(&configFile, "c", "/etc/parsemap.ini", "Configuration file path")
	flag.Parse()

	config = MustDict{ini.MustLoad(configFile)}
}

/**
 * Main
 */

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())

	role := config.mustGetString("postgres", "role")
	database := config.mustGetString("postgres", "database")
	ip := config.mustGetString("postgres", "ip")
	password := config.mustGetString("postgres", "password")
	services.InitDBConnection(role, password, database, ip)

	api_key := config.mustGetString("parsemap", "api_key")
	r := gin.New()
	r.Use(gzip.Gzip(gzip.DefaultCompression))
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(gin.ErrorLogger())

	v2 := r.Group("/v2")
	services.GetHandlersV2(v2, api_key)

	var wg sync.WaitGroup
	wg.Add(2)
	go startServer(r, &wg)
	go startTLSServer(r, &wg)
	wg.Wait()
}

func startServer(r *gin.Engine, wg *sync.WaitGroup) {
	defer wg.Done()

	listen := httpListenString()
	r.Run(listen)
}

func startTLSServer(r *gin.Engine, wg *sync.WaitGroup) {
	defer wg.Done()

	crtFile := config.mustGetString("parsemap", "crt_file")
	keyFile := config.mustGetString("parsemap", "key_file")
	listen := httpsListenString()
	r.RunTLS(listen, crtFile, keyFile)
}
