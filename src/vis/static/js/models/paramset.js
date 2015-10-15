var app = app || {};


app.ParamSet = Backbone.Model.extend({

    // Default attributes ensure that each todo created has `title` and `completed` keys.
    defaults: {
      params: {},
      traces: []
    },

    // Toggle the `completed` state of this todo item.
    // toggle: function() {
    //   this.save({
    //     completed: !this.get('completed')
    //   });
    // }

});
