var app = app || {};


app.Execution = Backbone.Model.extend({

    // Default attributes ensure that each todo created has `title` and `completed` keys.
    defaults: {
      paramSets: []
    },

    // Toggle the `completed` state of this todo item.
    // toggle: function() {
    //   this.save({
    //     completed: !this.get('completed')
    //   });
    // }

});
