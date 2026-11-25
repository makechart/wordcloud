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
  # 扣掉 margin 後的排版範圍
  area = ({cfg, box}) ->
    m = Math.max(0, +cfg.margin or 0)
    {m, width: Math.max(0, box.width - 2 * m), height: Math.max(0, box.height - 2 * m)}
  sample: ->
    # 少數大字 + 一堆小字
    raw: <[cover scandal seem consumption garbage hunter pepper west guilt conspiracy
    ]>.map((d, i) -> {text: d, value: 8 * i + 10}) ++ <[
      pupil boat muscle nightmare gene royalty salon difficult management brainstorm
      aid moving plaster cake issue realism subject speed railcar break
      grass collapse is leave retiree looting transaction copyright serve guard
      colony spell ask ranch cell sensation name default reflection pebble
      lantern orbit velvet meadow thistle ember quill harbor cinder willow
      fable prism nectar ripple sparrow cobalt dune juniper lattice marble
      nimbus oyster parcel quartz saffron tundra umbra vessel walnut yarrow
      zephyr anchor bramble canopy delta fern glacier hollow ivory jasmine
      kettle lagoon mosaic nutmeg opal pylon quiver raven sable timber
      upland violet wander xenon yonder zenith amber beacon cobble drift
      echo flint garnet heron inlet jetty kelp linen mango nomad
      olive pixel quokka relic shale tango ultra vapor wisp yodel
    ]>.map (d, i) -> {text: d, value: 1 + (i % 7) * 0.4}
    binding:
      value: {key: \value}
      text: {key: \text}

  config:
    palette: type: \palette, desc: {en: "colors of the words, picked by each word's value; without one, a rainbow scale is used", "zh-TW": "文字的配色，依各個詞的數值取色；沒有設定時使用彩虹色階"}
    color:
      random: type: \boolean, default: false, desc: {en: "color each word by its text instead of its value", "zh-TW": "依詞的文字決定顏色，而不是依數值"}
    background: type: \color, default: \#fff
    # base 會把它設成 root 的 padding; 排版時另外扣掉 ( svg 疊在左上角, 不受 padding 影響 )
    margin: type: \number, default: 0, min: 0, max: 200, step: 1, desc: {en: "space around the chart, in px", "zh-TW": "圖表四周的留白 ( px )"}
    font:
      size: type: \number, min: 1, max: 256, step: 1, default: 64, desc: {en: "font size of the largest word; others scale with the square root of their value ( px )", "zh-TW": "最大的詞的字級，其它詞依數值的平方根等比縮小 ( px )"}
      family: type: \font
    cloud:
      padding: type: \number, default: 2, min: 0, max: 50, step: 1, desc: {en: "space between the words ( px )", "zh-TW": "詞與詞之間的間距 ( px )"}
      rotate:
        angle: type: \number, default: 0, min: 0 max: 360, step: 0.1, desc: {en: "base rotation of the words ( degrees )", "zh-TW": "文字的基本旋轉角度 ( 度 )"}
        variant: type: \number, default: 15, min: 0, max: 180, step: 0.1, desc: {en: "each word is rotated by a random extra angle within plus or minus this value ( degrees )", "zh-TW": "每個詞再隨機多轉正負這個角度以內 ( 度 )"}

  # 段落 ( tab ) 的說明, key 是段落的路徑. preset 的段落由 chart.utils.config.tabinfo 掛上來, 共用的 common 由核心補
  tabinfo:
    color: desc: {en: "how the words are colored", "zh-TW": "文字的上色方式"}
    cloud: desc: {en: "how the words are laid out in the cloud", "zh-TW": "文字雲裡文字的排列"}
    "cloud/rotate": desc: {en: "how much the words are rotated", "zh-TW": "文字的旋轉角度"}
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
      .fontSize ~> @cfg.font.size * it.value
      # 只畫排得進去的詞 ( end 給的 ), 排不進去的不畫; 不然會用上一次嘗試留下的座標畫到框外
      .on \end, (words) ~>
        @placed = words
        @render!
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
      .padding Math.max(0, +@cfg.cloud.padding or 0)
      .size([area(@).width, area(@).height].map -> Math.round it)
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
    {m, width, height} = area @
    tj = join root: @svg, tag: \text, data: (@placed or [])
    tj.exit.map -> it.remove!
    Array.from(@svg.querySelectorAll ':scope > text').map (n) ~>
      d = n.__data__
      n.setAttribute \transform, "translate(#{d.x + m + width / 2} #{d.y + m + height / 2}) rotate(#{d.rotate})"
      n.setAttribute \text-anchor, \middle
      n.setAttribute \font-size, d.size
      n.setAttribute \font-family, @fonts.name!
      n.setAttribute \fill, if @cfg.color.random => @tint.get d.text else color vscale d.value
      n.textContent = d.text
  tick: ->
