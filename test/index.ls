# wordcloud 的 test case ( @makechart/viewer 的 mctest )
words = <[cover scandal seem consumption garbage hunter pepper west guilt conspiracy pupil boat muscle
  nightmare gene royalty salon difficult management brainstorm aid moving plaster cake issue realism]>
mk = (n) -> raw: words.slice(0, n).map((text, i) -> {text, value: 1.5 * i + 10}), binding: {value: {key: \value}, text: {key: \text}}
# 排版是非同步的 ( d3-cloud 的 timer ), 等它跑完
layout = (c, ctx) -> ctx.wait 1500

mctest.suite do
  size: [480, 360]
  data:
    many: mk 26
    few: mk 6
  cases:
    * name: "many", data: \many, steps: layout
    * name: "few", data: \few, steps: layout
    * name: "font-size", data: \many, config: {font: {size: 40}}, steps: layout
    * name: "rotate", data: \many, config: {cloud: {rotate: {angle: 30, variant: 30}}}, steps: layout
    * name: "random-color", data: \few, config: {color: {random: true}}, steps: layout
    * name: "palette", data: \few, config: {palette: {colors: <[#f00 #0a0 #00f]>}}, steps: layout
