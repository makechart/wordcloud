(function(){
  var mod;
  module.exports = {
    pkg: {
      name: 'wordcloud',
      version: '0.0.1',
      extend: {
        name: "base",
        version: "0.0.1"
      },
      dependencies: [
        {
          url: "https://unpkg.com/d3-cloud@1.2.5/build/d3.layout.cloud.js"
        }, {
          name: "@xlfont/load",
          version: "main"
        }
      ]
    },
    init: function(arg$){
      var root, ctx, pubsub;
      root = arg$.root, ctx = arg$.ctx, pubsub = arg$.pubsub;
      return pubsub.fire('init', {
        mod: mod({
          ctx: ctx
        }),
        layout: false
      }).then(function(it){
        return it[0];
      });
    }
  };
  mod = function(arg$){
    var ctx, root, d3, forceBoundary, ldcolor, chart, xfl;
    ctx = arg$.ctx, root = arg$.root;
    d3 = ctx.d3, forceBoundary = ctx.forceBoundary, ldcolor = ctx.ldcolor, chart = ctx.chart, xfl = ctx.xfl;
    return {
      sample: function(){
        return {
          raw: ['cover', 'scandal', 'seem', 'consumption', 'garbage', 'hunter', 'pepper', 'west', 'guilt', 'conspiracy', 'pupil', 'boat', 'muscle', 'nightmare', 'gene', 'royalty', 'salon', 'difficult', 'management', 'brainstorm', 'aid', 'moving', 'plaster', 'cake', 'issue', 'realism', 'subject', 'speed', 'railcar', 'break', 'grass', 'collapse', 'is', 'leave', 'retiree', 'looting', 'transaction', 'copyright', 'serve', 'guard', 'colony', 'spell', 'ask', 'ranch', 'cell', 'sensation', 'name', 'default', 'reflection'].map(function(d, i){
            return {
              text: d,
              value: 1.5 * i + 10
            };
          }),
          binding: {
            value: {
              key: 'value'
            },
            text: {
              key: 'text'
            }
          }
        };
      },
      config: {
        palette: {
          type: 'palette'
        },
        color: {
          random: {
            type: 'boolean',
            'default': false
          }
        },
        background: {
          type: 'color'
        },
        font: {
          size: {
            type: 'number',
            min: 1,
            max: 256,
            step: 1,
            'default': 64
          },
          family: {
            type: 'font'
          }
        },
        cloud: {
          rotate: {
            angle: {
              type: 'number',
              'default': 0,
              min: 0,
              max: 360,
              step: 0.1
            },
            variant: {
              type: 'number',
              'default': 0,
              min: 0,
              max: 180,
              step: 0.1
            }
          }
        }
      },
      dimension: {
        value: {
          type: 'R',
          name: "size"
        },
        text: {
          type: 'NCO',
          name: "name"
        }
      },
      init: function(){
        var tint, this$ = this;
        this.tint = tint = new chart.utils.tint();
        this.cloud = d3.layout.cloud();
        this.cloud.canvas(function(){
          var ret, ctx;
          ret = document.createElement('canvas');
          ctx = ret.getContext('2d', {
            willReadFrequently: true
          });
          return ret;
        }).rotate(function(){
          var a, v;
          a = this$.cfg.cloud.rotate.angle || 0;
          v = this$.cfg.cloud.rotate.variant || 0;
          return a + v * (Math.random() * 2 - 1);
        }).padding(2).fontSize(function(it){
          return this$.cfg.font.size * it.value;
        }).on('end', function(){
          return this$.render();
        });
        return this.fonts = {
          h: {},
          active: null,
          name: function(){
            return (this$.fonts.active || {}).name || (this$.cfg.font.family || {}).name || 'arial';
          }
        };
      },
      parse: function(){
        var font, this$ = this;
        this.parsed = this.data.map(function(it){
          var ret;
          ret = import$({}, it);
          ret._value = ret.value;
          ret.value = Math.sqrt(ret._value);
          return ret;
        });
        this._max = Math.max.apply(Math, this.parsed.map(function(it){
          return it.value;
        }));
        this.parsed.map(function(it){
          return it.value = it.value / this$._max;
        });
        if (this.cfg.font.family) {
          console.log(this.cfg.font.family.isXl);
        }
        if (this.cfg.font.family && this.cfg.font.family.isXl) {
          if (!(font = this.fonts.h[this.cfg.font.family.path])) {
            this.fonts.h[this.cfg.font.family.path] = {
              loading: true
            };
            xfl.load(this.cfg.font.family.path).then(function(font){
              this$.fonts.h[this$.cfg.font.family.path] = this$.fonts.active = font;
              if (!font.sync) {
                return;
              }
              return font.sync(this$.parsed.map(function(it){
                return it.text;
              }).join('')).then(function(){
                this$.resize();
                return this$.render();
              });
            });
          }
          if (font && font.sync) {
            return font.sync(this.parsed.map(function(it){
              return it.text;
            }).join('')).then(function(){
              this$.resize();
              return this$.render();
            });
          }
        }
      },
      resize: function(){
        this.cloud.size([this.box.width, this.box.height].map(function(it){
          return Math.round(it);
        })).words(this.parsed).font(this.fonts.name()).start();
        return this.tint.set(this.cfg.palette.colors);
      },
      render: function(){
        var color, vext, vscale, x$, this$ = this;
        color = d3.interpolateTurbo;
        if (this.cfg != null && this.cfg.palette) {
          color = d3.interpolateDiscrete(this.cfg.palette.colors.map(function(it){
            return ldcolor.web(it.value || it);
          }));
        }
        vext = d3.extent(this.parsed.map(function(it){
          return it.value;
        }));
        vscale = d3.scaleLinear().domain(vext).range([0, 1]);
        x$ = d3.select(this.svg).selectAll('text').data(this.parsed);
        x$.exit().remove();
        x$.enter().append('text');
        return d3.select(this.svg).selectAll('text').attr('transform', function(it){
          return "translate(" + (it.x + this$.box.width / 2) + " " + (it.y + this$.box.height / 2) + ") rotate(" + it.rotate + ")";
        }).attr('text-anchor', 'middle').attr('font-size', function(it){
          return it.size;
        }).attr('font-family', this.fonts.name()).attr('fill', function(it){
          if (this$.cfg.color.random) {
            return this$.tint.get(it.text);
          } else {
            return color(vscale(it.value));
          }
        }).text(function(it){
          return it.text;
        });
      },
      tick: function(){}
    };
  };
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
}).call(this);
