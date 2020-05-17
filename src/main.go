package main

import (
	"encoding/gob"
	"flag"
	"github.com/pepelazz/projectBlueprint/src/graylog"
	"github.com/pepelazz/projectBlueprint/src/jobs"
	"github.com/pepelazz/projectBlueprint/src/pg"
	"github.com/pepelazz/projectBlueprint/src/types"
	"github.com/pepelazz/projectBlueprint/src/utils"
	"github.com/pepelazz/projectBlueprint/src/webServer"
	"github.com/pepelazz/projectBlueprint/src/sse"
	"math/rand"
	"os"
	"time"
)

var (
	config *types.Config
	err    error
)

func main() {

	// считываем флаг dev. Если режим разработки, то меняем глобальные переменные
	isDev := flag.Bool("dev", false, "a bool")
	flag.Parse()

	if *isDev {
		
		_ = os.Setenv("PG_HOST", "localhost")
		_ = os.Setenv("IS_DEVELOPMENT", "true")
	}

	// read config.toml
	config, err = types.ReadConfigFile("./config.toml")
	utils.CheckErr(err, "Read config")

	// postgres
	err = pg.StartPostgres(config.Postgres)
	utils.CheckErr(err, "StartPostgres")

	// подключаемся к серверу сбора логов
	err = graylog.Init(config.Graylog)
	utils.CheckErr(err, "Connect to GraylogConfig")

	// инициализируем генератор случайных чисел
	rand.Seed(time.Now().UnixNano())
	//
	gob.Register(map[string]interface{}{})
	//
	jobs.StartJobs()

	// передаем часть конфига в utils
	utils.SetWebServerConfig(config.WebServer)
	utils.SetEmailConfig(config.Email)

	//go pg.GenerateFakeUsers(100)

	// инициализируем брокера для обработки подключений по SSE
	sse.Init()

	webServer.StartWebServer(*config)
}
