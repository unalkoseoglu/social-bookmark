// Action.js
// Safari'den URL ve sayfa bilgilerini almak için JavaScript preprocessing

var Action = function() {};

Action.prototype = {
    
    // Safari sayfayı yüklediğinde çağrılır
    run: function(arguments) {
        // Sayfa bilgilerini topla
        arguments.completionFunction({
            "URL": document.URL,
            "title": document.title,
            "selection": document.getSelection().toString()
        });
    },
    
    // Extension işlemi tamamlandığında çağrılır (opsiyonel)
    finalize: function(arguments) {
        // Extension'dan geri dönen veriyi işle (gerekirse)
    }
    
};

var ExtensionPreprocessingJS = new Action;
