module.exports =
  pkg:
    name: 'wordcloud', version: '0.0.1'
    extend: {name: "base", version: "0.0.1"}
    dependencies: [
      {url: "https://unpkg.com/d3-cloud@1.2.5/build/d3.layout.cloud.js"}
      {name: "@xlfont/load", version: "main"}
    ]

  init: ({root, ctx, pubsub}) ->
    pubsub.fire \init, mod: mod({ctx}), layout: false
      .then ~> it.0

mod = ({ctx, root}) ->
  {d3, forceBoundary, ldcolor, chart, xfl} = ctx
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
        a + v * (Math.random! * 2 - 1)
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

    if @cfg.font.family => console.log @cfg.font.family.isXl
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
    @cloud
      .size([@box.width, @box.height].map -> Math.round it)
      .words @parsed
      .font @fonts.name!
      .start!
    @tint.set @cfg.palette.colors
  render: ->
    color = d3.interpolateTurbo
    if @cfg? and @cfg.palette =>
      color = d3.interpolateDiscrete @cfg.palette.colors.map -> ldcolor.web(it.value or it)
    vext = d3.extent @parsed.map -> it.value
    vscale = d3.scaleLinear!domain vext .range [0,1]
    d3.select @svg .selectAll \text .data @parsed
      ..exit!remove!
      ..enter!append \text
    d3.select @svg .selectAll \text
      .attr \transform, ~> "translate(#{it.x + @box.width / 2} #{it.y + @box.height / 2}) rotate(#{it.rotate})"
      .attr \text-anchor, \middle
      .attr \font-size, -> it.size
      .attr \font-family, @fonts.name!
      .attr \fill, ~>
        if @cfg.color.random => @tint.get it.text
        else color vscale it.value
      .text -> it.text
  tick: ->
