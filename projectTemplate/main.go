package main

import (
	"os"

	"github.com/NL-A/nla_framework"
	t "github.com/NL-A/nla_framework/types"
	"github.com/NL-A/projectBlueprint/projectTemplate/docs/legalEntity"
	"github.com/NL-A/projectBlueprint/projectTemplate/utils"
	"github.com/otiai10/copy"
)

func main() {
	nla_framework.Start(getProject(), nil)
}

func getProject() t.ProjectType {
	p := &t.ProjectType{
		Name: "CompanyName",
	}
	p.Config.Vue.QuasarVersion = 2
	p.FillI18n()

	p.Docs = []t.DocType{
		legalEntity.GetDoc(p),
	}
	// названием базы маленькими буквами, без пробелов
	p.Config.Postgres = t.PostrgesConfig{DbName: "db_name", Port: 5646, Password: "xvzDV4curLidx8IWZJ6czDHQ1qa7wjfL", TimeZone: "Asia/Novosibirsk", Version: "13"}
	p.Config.WebServer = t.WebServerConfig{Port: 3091, Url: "https://example.ru", Path: "/home/deploy/projectName", Ip: "85.210.890.567", Username: "root"}
	// TODO: надо прописать настройки почтового сервера для отправки email
	p.Config.Email = t.EmailConfig{Sender: "info@mail.ru", Password: "password", Host: "smtp.mail.ru", Port: 465, SenderName: "CompanyName"}
	p.Config.Logo = "https://i.pinimg.com/564x/05/57/1d/05571dac600004278124d12b5a567ddb.jpg"
	// формируем routes для Vue
	p.FillVueBaseRoutes()
	p.Vue.UiAppName = "CompanyName"

	// боковое меню для Vue
	p.Vue.Menu = []t.VueMenu{
		//{DocName: "client_order"},
		{Url: "users", Text: "Пользователи", Icon: "image/users.svg", Roles: []string{utils.RoleAdmin}},
		{DocName: "legal_entity"},
		{Text: "Справочники", Icon: "image/directory.png", IsFolder: true, LinkList: []t.VueMenu{{DocName: "legal_entity"}}},
	}
	p.FillSideMenu()

	// копируем файлы проекта (которые не шаблоны)
	if _, err := os.Stat("./sourceFiles"); !os.IsNotExist(err) {
		err := copy.Copy("./sourceFiles", "../")
		utils.CheckErr(err, "Copy sourceFiles")
	}

	return *p
}
