# contracts/ 说明

本目录保存 EC-API-0.1 派生的客户端 fixture。canonical schema/OpenAPI 由 Python 后端仓库维护（尚未创建），本仓库不自行定义远端接口。

- 契约版本：EC-API-0.1（设计初稿），唯一权威定义见 [docs/planning/TechnicalDesign.md](../docs/planning/TechnicalDesign.md) 第 5 节
- 冻结缺口：第 5.6 节列出的 schema 缺口未冻结；fixture 仅覆盖已明确的字段形状，未冻结部分不猜字段
- fixtures/ 内为原创演示数据（虚构教材、虚构儿童昵称），不含真实教材内容、真实儿童录音或个人数据
- 界面与测试消费这些 fixture 时须标注"模拟服务/演示数据"
