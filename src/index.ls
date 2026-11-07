module.exports =
  pkg:
    name: 'wordcloud', version: '0.0.1'
    # lite: 不帶 d3 的 base ( 見 @plotdb/chart utils )
    extend: {name: "@makechart/base", path: "lite/index.html"}
    # d3-cloud 的 build 已內含 d3-dispatch, 不需要 d3 core
    dependencies: [
      {name: "d3-cloud", version: "1.2.5", path: "build/d3.layout.cloud.js", async: false}
      {name: "@xlfont/load", version: "main"}
    ]

  init: ({root, ctx, pubsub}) ->
    pubsub.fire \init, mod: mod({ctx}), layout: false
      .then ~> it.0

mod = ({ctx, root}) ->
  {d3, ldcolor, chart, xfl} = ctx
  {scale: Scale, color: {turbo, discrete}, anim: {join}} = chart.utils
  # 同 d3.randomLcg ( 移植自 d3-random, ISC )
  lcg = (seed) ->
    [mul, inc, eps] = [0x19660D, 0x3C6EF35F, 1 / 0x100000000]
    state = (if 0 <= seed and seed < 1 => seed / eps else Math.abs(seed)) .|. 0
    -> eps * ((state := (mul * state + inc) .|. 0) .>>>. 0)
  # 同 d3.extent: 略過 null / NaN
  extent = (list) ->
    vs = list.filter -> it? and +it >= +it
    if vs.length => [vs.reduce(((a,b) -> if b < a => b else a)), vs.reduce(((a,b) -> if b > a => b else a))]
    else [undefined, undefined]
  sample: ->
    raw: <[cover scandal seem consumption garbage hunter
      pepper west guilt conspiracy pupil boat muscle nightmare gene
      royalty salon difficult management brainstorm aid moving plaster
      cake issue realism subject speed railcar break grass collapse
      is leave retiree looting transaction copyright serve guard
      colony spell ask ranch cell sensation name default reflection
    ]>.map (d, i) -> {text: d, value: 1.5 * i + 10}
    binding:
      value: {key: \value}
      text: {key: \text}

  config:
    palette: type: \palette
    color:
      random: type: \boolean, default: false
    background: type: \color
    font:
      size: type: \number, min: 1, max: 256, step: 1, default: 64
      family: type: \font
    cloud:
      rotate:
        angle: type: \number, default: 0, min: 0 max: 360, step: 0.1
        variant: type: \number, default: 0, min: 0, max: 180, step: 0.1

  dimension:
    value: {type: \R, name: "size"}
    text: {type: \NCO, name: "name"}

  init: ->
    # 沒有 layout 時 svg 接在 base 的 layout 區塊後面, 會被擠到可視範圍外; 疊回左上角
    @svg.style <<< position: \absolute, left: 0, top: 0
    @tint = tint = new chart.utils.tint!
    @cloud = d3.layout.cloud!
    @cloud
      .canvas ~>
        ret = document.createElement \canvas
        ctx = ret.getContext \2d, {willReadFrequently: true}
        ret
      .rotate ~>
        a = @cfg.cloud.rotate.angle or 0
        v = @cfg.cloud.rotate.variant or 0
        a + v * (@rng! * 2 - 1)
      .padding 2
      .fontSize ~> @cfg.font.size * it.value
      .on \end, ~> @render!
    @fonts =
      h: {},
      active: null
      name: ~> (@fonts.active or {}).name or (@cfg.font.family or {}).name or \arial
  parse: ->
    @parsed = @data.map ->
      ret = {} <<< it
      ret._value = ret.value
      ret.value = Math.sqrt(ret._value)
      ret
    @_max = Math.max.apply Math, @parsed.map -> it.value
    @parsed.map ~> it.value = it.value / @_max

    if @cfg.font.family and @cfg.font.family.isXl =>
      if !(font = @fonts.h[@cfg.font.family.path]) =>
        @fonts.h[@cfg.font.family.path] = {loading: true}
        xfl.load @cfg.font.family.path .then (font) ~>
          @fonts.h[@cfg.font.family.path] = @fonts.active = font
          if !font.sync => return
          font.sync @parsed.map(-> it.text).join('')
            .then ~>
              @resize!
              @render!
      if font and font.sync =>
        font.sync @parsed.map(-> it.text).join('')
          .then ~>
            @resize!
            @render!

  resize: ->
    # 排版與旋轉用固定種子的亂數: 同樣的資料與設定每次排出一樣的結果 ( 原本用 Math.random, 每次重排都不同 )
    @rng = lcg 1
    @cloud
      .random @rng
      .size([@box.width, @box.height].map -> Math.round it)
      .words @parsed
      .font @fonts.name!
      .start!
    if @cfg.palette => @tint.set @cfg.palette.colors
  render: ->
    color = turbo
    if @cfg? and @cfg.palette =>
      color = discrete @cfg.palette.colors.map -> ldcolor.web(it.value or it)
    vext = extent @parsed.map -> it.value
    vscale = Scale.linear!domain vext .range [0,1]
    tj = join root: @svg, tag: \text, data: @parsed
    tj.exit.map -> it.remove!
    Array.from(@svg.querySelectorAll ':scope > text').map (n) ~>
      d = n.__data__
      n.setAttribute \transform, "translate(#{d.x + @box.width / 2} #{d.y + @box.height / 2}) rotate(#{d.rotate})"
      n.setAttribute \text-anchor, \middle
      n.setAttribute \font-size, d.size
      n.setAttribute \font-family, @fonts.name!
      n.setAttribute \fill, if @cfg.color.random => @tint.get d.text else color vscale d.value
      n.textContent = d.text
  tick: ->
