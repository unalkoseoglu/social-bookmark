//
//  IconCategory.swift
//  Social Bookmark
//
//  Created by Ünal Köseoğlu on 25.12.2025.
//


//
//  SFSymbolsIcons.swift
//  Social Bookmark
//
//  SF Symbols ikon koleksiyonu (1500+ ikon)
//

import SwiftUI

// MARK: - Icon Category Model

struct IconCategory: Identifiable {
    let id = UUID()
    let name: LocalizedStringKey
    let icons: [String]
}

// MARK: - Category Design

struct CategoryDesign {
    
    // İlk 18 ikon (3 satır x 6 sütun) - en popüler olanlar
    static let quickIcons: [String] = [
        "folder.fill", "star.fill", "heart.fill", "bookmark.fill", "tag.fill", "flag.fill",
        "briefcase.fill", "doc.fill", "book.fill", "graduationcap.fill", "lightbulb.fill", "gear",
        "cart.fill", "creditcard.fill", "house.fill", "car.fill", "airplane", "globe"
    ]
    
    // Renkler
    static let colors: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow,
        .green, .mint, .teal, .cyan, .indigo, .brown,
        .gray, .black, .accentColor
    ]
    
    // Tüm ikonlar - kategorilere ayrılmış
    static let allIcons: [IconCategory] = [
        
        // MARK: - Genel & Dosya
        IconCategory(name: "category.icons.general", icons: [
            "folder.fill", "folder.circle.fill", "folder.badge.plus", "folder.badge.minus",
            "folder.badge.gear", "folder.badge.person.crop", "folder.badge.questionmark",
            "archivebox.fill", "archivebox.circle.fill", "tray.fill", "tray.circle.fill",
            "tray.full.fill", "tray.and.arrow.up.fill", "tray.and.arrow.down.fill",
            "tray.2.fill", "externaldrive.fill", "externaldrive.badge.plus",
            "externaldrive.badge.minus", "externaldrive.badge.checkmark", "externaldrive.badge.xmark",
            "externaldrive.badge.person.crop", "externaldrive.badge.icloud", "externaldrive.badge.wifi",
            "internaldrive.fill", "opticaldiscdrive.fill", "doc.fill", "doc.circle.fill",
            "doc.badge.plus", "doc.badge.arrow.up.fill", "doc.badge.ellipsis",
            "doc.text.fill", "doc.richtext.fill", "doc.plaintext.fill", "doc.append.fill",
            "doc.text.below.ecg.fill", "doc.on.doc.fill", "doc.on.clipboard.fill",
            "clipboard.fill", "list.clipboard.fill", "list.bullet.clipboard.fill",
            "note.text", "note.text.badge.plus", "square.and.pencil", "pencil.and.outline",
            "square.and.arrow.up.fill", "square.and.arrow.down.fill",
            "rectangle.portrait.and.arrow.right.fill", "rectangle.portrait.and.arrow.forward.fill"
        ]),
        
        // MARK: - Kitap & Okuma
        IconCategory(name: "category.icons.books", icons: [
            "book.fill", "book.circle.fill", "book.closed.fill", "book.and.wrench.fill",
            "books.vertical.fill", "books.vertical.circle.fill", "book.pages.fill",
            "character.book.closed.fill", "text.book.closed.fill", "menucard.fill",
            "magazine.fill", "newspaper.fill", "newspaper.circle.fill",
            "bookmark.fill", "bookmark.circle.fill", "bookmark.square.fill", "bookmark.slash.fill",
            "rosette", "graduationcap.fill", "graduationcap.circle.fill",
            "pencil", "pencil.circle.fill", "pencil.slash", "pencil.line",
            "pencil.and.ruler.fill", "pencil.tip", "pencil.tip.crop.circle.fill",
            "lasso", "lasso.badge.sparkles", "trash.fill", "trash.circle.fill",
            "trash.slash.fill", "xmark.bin.fill", "xmark.bin.circle.fill",
            "list.bullet", "list.dash", "list.number", "list.star",
            "text.alignleft", "text.aligncenter", "text.alignright", "text.justify"
        ]),
        
        // MARK: - İletişim
        IconCategory(name: "category.icons.communication", icons: [
            "envelope.fill", "envelope.circle.fill", "envelope.badge.fill",
            "envelope.badge.shield.half.filled.fill", "envelope.open.fill",
            "envelope.arrow.triangle.branch.fill", "paperplane.fill", "paperplane.circle.fill",
            "bubble.fill", "bubble.circle.fill", "bubble.left.fill", "bubble.right.fill",
            "bubble.left.circle.fill", "bubble.right.circle.fill",
            "bubble.left.and.bubble.right.fill", "bubble.middle.bottom.fill",
            "bubble.middle.top.fill", "bubble.left.and.text.bubble.right.fill",
            "exclamationmark.bubble.fill", "exclamationmark.bubble.circle.fill",
            "quote.bubble.fill", "star.bubble.fill", "character.bubble.fill",
            "text.bubble.fill", "captions.bubble.fill", "plus.bubble.fill",
            "checkmark.bubble.fill", "rectangle.3.group.bubble.fill",
            "ellipsis.bubble.fill", "ellipsis.vertical.bubble.fill",
            "phone.fill", "phone.circle.fill", "phone.badge.plus",
            "phone.connection.fill", "phone.fill.arrow.up.right", "phone.fill.arrow.down.left",
            "phone.arrow.up.right.fill", "phone.arrow.down.left.fill",
            "phone.down.fill", "phone.down.circle.fill", "phone.and.waveform.fill",
            "teletype.fill", "teletype.circle.fill", "video.fill", "video.circle.fill",
            "video.slash.fill", "video.badge.plus", "video.badge.checkmark",
            "video.fill.badge.plus", "video.fill.badge.checkmark",
            "arrow.up.right.video.fill", "arrow.down.left.video.fill",
            "questionmark.video.fill", "envelope.open.badge.clock",
            "message.fill", "message.circle.fill", "message.badge.fill",
            "ellipsis.message.fill", "bubble.left.and.exclamationmark.bubble.right.fill"
        ]),
        
        // MARK: - İnsanlar
        IconCategory(name: "category.icons.people", icons: [
            "person.fill", "person.circle.fill", "person.badge.plus",
            "person.badge.minus", "person.badge.clock.fill", "person.badge.key.fill",
            "person.badge.shield.checkmark.fill", "person.fill.turn.right",
            "person.fill.turn.left", "person.fill.turn.down", "person.fill.checkmark",
            "person.fill.xmark", "person.fill.questionmark", "person.fill.badge.plus",
            "person.fill.badge.minus", "person.fill.viewfinder",
            "person.2.fill", "person.2.circle.fill", "person.2.badge.plus.fill",
            "person.2.badge.minus.fill", "person.2.badge.gearshape.fill",
            "person.2.slash.fill", "person.2.wave.2.fill",
            "person.3.fill", "person.3.sequence.fill",
            "person.crop.circle.fill", "person.crop.circle.badge.plus",
            "person.crop.circle.badge.minus", "person.crop.circle.badge.checkmark",
            "person.crop.circle.badge.xmark", "person.crop.circle.badge.questionmark",
            "person.crop.circle.badge.exclamationmark", "person.crop.circle.badge.moon",
            "person.crop.circle.badge", "person.crop.circle.dashed",
            "person.crop.square.fill", "person.crop.square.filled.and.at.rectangle.fill",
            "person.crop.rectangle.fill", "person.crop.rectangle.stack.fill",
            "person.crop.artframe", "shared.with.you", "shareplay",
            "figure.stand", "figure.walk", "figure.walk.circle.fill",
            "figure.wave", "figure.wave.circle.fill", "figure.run",
            "figure.run.circle.fill", "figure.roll", "figure.fall",
            "figure.fall.circle.fill", "figure.2.arms.open", "figure.2.and.child.holdinghands",
            "figure.and.child.holdinghands", "figure.dress.line.vertical.figure"
        ]),
        
        // MARK: - Spor & Fitness
        IconCategory(name: "category.icons.sports", icons: [
            "figure.american.football", "figure.archery", "figure.australian.football",
            "figure.badminton", "figure.barre", "figure.baseball", "figure.basketball",
            "figure.bowling", "figure.boxing", "figure.climbing", "figure.cooldown",
            "figure.core.training", "figure.cricket", "figure.cross.training",
            "figure.curling", "figure.dance", "figure.disc.sports",
            "figure.elliptical", "figure.equestrian.sports", "figure.fencing",
            "figure.fishing", "figure.flexibility", "figure.golf",
            "figure.gymnastics", "figure.hand.cycling", "figure.handball",
            "figure.highintensity.intervaltraining", "figure.hiking",
            "figure.hockey", "figure.hunting", "figure.indoor.cycle",
            "figure.jumprope", "figure.kickboxing", "figure.lacrosse",
            "figure.martial.arts", "figure.mind.and.body", "figure.mixed.cardio",
            "figure.open.water.swim", "figure.outdoor.cycle", "figure.pickleball",
            "figure.pilates", "figure.play", "figure.pool.swim",
            "figure.racquetball", "figure.rolling", "figure.rower",
            "figure.rugby", "figure.sailing", "figure.skating",
            "figure.skiing.crosscountry", "figure.skiing.downhill", "figure.snowboarding",
            "figure.soccer", "figure.socialdance", "figure.softball",
            "figure.squash", "figure.stair.stepper", "figure.stairs",
            "figure.step.training", "figure.surfing", "figure.table.tennis",
            "figure.taichi", "figure.tennis", "figure.track.and.field",
            "figure.volleyball", "figure.water.fitness", "figure.waterpolo",
            "figure.wrestling", "figure.yoga",
            "sportscourt.fill", "sportscourt.circle.fill",
            "soccerball", "soccerball.inverse", "baseball.fill",
            "basketball.fill", "football.fill", "tennis.racket",
            "tennisball.fill", "hockey.puck.fill", "cricket.ball.fill",
            "dumbbell.fill", "figure.strengthtraining.traditional",
            "figure.strengthtraining.functional"
        ]),
        
        // MARK: - Doğa & Hava
        IconCategory(name: "category.icons.nature", icons: [
            "sun.min.fill", "sun.max.fill", "sun.max.circle.fill",
            "sun.max.trianglebadge.exclamationmark.fill", "sunrise.fill", "sunset.fill",
            "sun.and.horizon.fill", "sun.dust.fill", "sun.haze.fill", "sun.rain.fill",
            "sun.snow.fill", "moon.fill", "moon.circle.fill",
            "moon.zzz.fill", "moon.stars.fill", "moon.stars.circle.fill",
            "zzz", "sparkle", "sparkles", "moon.haze.fill", "sun.horizon.fill",
            "cloud.fill", "cloud.circle.fill", "cloud.drizzle.fill", "cloud.drizzle.circle.fill",
            "cloud.rain.fill", "cloud.rain.circle.fill", "cloud.heavyrain.fill",
            "cloud.heavyrain.circle.fill", "cloud.fog.fill", "cloud.fog.circle.fill",
            "cloud.hail.fill", "cloud.hail.circle.fill", "cloud.sleet.fill",
            "cloud.sleet.circle.fill", "cloud.snow.fill", "cloud.snow.circle.fill",
            "cloud.bolt.fill", "cloud.bolt.circle.fill", "cloud.bolt.rain.fill",
            "cloud.bolt.rain.circle.fill", "cloud.sun.fill", "cloud.sun.circle.fill",
            "cloud.sun.rain.fill", "cloud.sun.rain.circle.fill", "cloud.sun.bolt.fill",
            "cloud.sun.bolt.circle.fill", "cloud.moon.fill", "cloud.moon.circle.fill",
            "cloud.moon.rain.fill", "cloud.moon.rain.circle.fill", "cloud.moon.bolt.fill",
            "cloud.moon.bolt.circle.fill", "smoke.fill", "smoke.circle.fill",
            "wind", "wind.circle.fill", "wind.snow", "wind.snow.circle.fill",
            "snowflake", "snowflake.circle.fill", "tornado", "tornado.circle.fill",
            "tropicalstorm", "tropicalstorm.circle.fill", "hurricane", "hurricane.circle.fill",
            "thermometer.sun.fill", "thermometer.snowflake", "thermometer.snowflake.circle.fill",
            "thermometer.low", "thermometer.medium", "thermometer.high",
            "humidity.fill", "drop.fill", "drop.circle.fill", "drop.triangle.fill",
            "flame.fill", "flame.circle.fill", "bolt.fill", "bolt.circle.fill",
            "leaf.fill", "leaf.circle.fill", "leaf.arrow.triangle.circlepath",
            "tree.fill", "tree.circle.fill", "mountain.2.fill", "mountain.2.circle.fill",
            "water.waves", "water.waves.slash", "water.waves.and.arrow.up",
            "fish.fill", "fish.circle.fill", "bird.fill", "bird.circle.fill",
            "tortoise.fill", "tortoise.circle.fill", "hare.fill", "hare.circle.fill",
            "ant.fill", "ant.circle.fill", "ladybug.fill", "ladybug.circle.fill",
            "lizard.fill", "lizard.circle.fill", "pawprint.fill", "pawprint.circle.fill",
            "teddybear.fill", "teddybear.circle.fill", "allergens.fill",
            "microbe.fill", "microbe.circle.fill", "carrot.fill"
        ]),
        
        // MARK: - Nesneler
        IconCategory(name: "category.icons.objects", icons: [
            "lightbulb.fill", "lightbulb.circle.fill", "lightbulb.slash.fill",
            "lightbulb.min.fill", "lightbulb.max.fill", "lightbulb.led.fill",
            "lightbulb.led.wide.fill", "lightbulb.2.fill",
            "flashlight.on.fill", "flashlight.off.fill",
            "lamp.desk.fill", "lamp.floor.fill", "lamp.ceiling.fill",
            "lamp.table.fill", "chandelier.fill", "light.recessed.fill",
            "tag.fill", "tag.circle.fill", "tag.square.fill", "tag.slash.fill",
            "gift.fill", "gift.circle.fill", "bag.fill", "bag.circle.fill",
            "bag.badge.plus", "bag.badge.minus", "bag.fill.badge.plus", "bag.fill.badge.minus",
            "cart.fill", "cart.circle.fill", "cart.badge.plus", "cart.badge.minus",
            "cart.fill.badge.plus", "cart.fill.badge.minus",
            "basket.fill", "creditcard.fill", "creditcard.circle.fill",
            "creditcard.trianglebadge.exclamationmark.fill",
            "banknote.fill", "dollarsign", "dollarsign.circle.fill", "dollarsign.square.fill",
            "eurosign", "eurosign.circle.fill", "yensign", "yensign.circle.fill",
            "sterlingsign", "sterlingsign.circle.fill",
            "turkishlirasign", "turkishlirasign.circle.fill",
            "bitcoinsign.circle.fill", "bitcoinsign.square.fill",
            "key.fill", "key.horizontal.fill", "key.icloud.fill",
            "lock.fill", "lock.circle.fill", "lock.square.fill",
            "lock.slash.fill", "lock.open.fill", "lock.rotation",
            "pin.fill", "pin.circle.fill", "pin.square.fill", "pin.slash.fill",
            "mappin", "mappin.circle.fill", "mappin.square.fill", "mappin.slash.fill",
            "mappin.and.ellipse", "map.fill", "map.circle.fill",
            "flag.fill", "flag.circle.fill", "flag.square.fill", "flag.slash.fill",
            "flag.2.crossed.fill", "flag.checkered", "flag.checkered.circle.fill",
            "bell.fill", "bell.circle.fill", "bell.square.fill", "bell.slash.fill",
            "bell.badge.fill", "bell.badge.circle.fill",
            "megaphone.fill", "eyeglasses", "sunglasses.fill", "binoculars.fill",
            "mustache.fill", "nose.fill", "mouth.fill",
            "facemask.fill", "theatermasks.fill", "theatermasks.circle.fill",
            "comb.fill", "crown.fill", "scissors", "scissors.badge.ellipsis"
        ]),
        
        // MARK: - Cihazlar
        IconCategory(name: "category.icons.devices", icons: [
            "iphone", "iphone.gen1", "iphone.gen2", "iphone.gen3",
            "iphone.circle.fill", "iphone.badge.play",
            "iphone.homebutton", "iphone.homebutton.circle.fill",
            "iphone.slash", "iphone.slash.circle.fill",
            "iphone.radiowaves.left.and.right", "iphone.radiowaves.left.and.right.circle.fill",
            "ipad", "ipad.homebutton", "ipad.landscape", "ipad.homebutton.landscape",
            "ipad.badge.play", "ipad.homebutton.badge.play",
            "ipad.and.iphone", "ipad.and.arrow.forward",
            "ipodtouch", "ipodtouch.landscape", "ipodtouch.slash",
            "applewatch", "applewatch.watchface", "applewatch.radiowaves.left.and.right",
            "applewatch.slash", "applewatch.side.right",
            "macbook", "macbook.gen2", "macbook.and.iphone", "macbook.and.ipad",
            "laptopcomputer", "laptopcomputer.slash",
            "laptopcomputer.and.iphone", "laptopcomputer.and.arrow.down",
            "desktopcomputer", "display", "display.2",
            "display.trianglebadge.exclamationmark", "pc", "macpro.gen1.fill",
            "macpro.gen2.fill", "macpro.gen3.fill", "server.rack",
            "macstudio.fill", "macmini.fill", "airport.express",
            "homepod.fill", "homepod.mini.fill", "homepod.2.fill", "homepod.and.homepod.mini.fill",
            "hifispeaker.fill", "hifispeaker.2.fill", "radio.fill",
            "tv.fill", "tv.circle.fill", "tv.slash.fill", "tv.badge.wifi.fill",
            "tv.and.hifispeaker.fill", "tv.and.mediabox.fill", "play.tv.fill",
            "appletvremote.gen1.fill", "appletvremote.gen2.fill",
            "appletvremote.gen3.fill", "appletvremote.gen4.fill",
            "headphones", "headphones.circle.fill", "earbuds", "earbuds.case.fill",
            "airpods", "airpodspro", "airpodspro.chargingcase.wireless.fill",
            "airpods.chargingcase.fill", "airpodsmax",
            "gamecontroller.fill", "keyboard.fill", "keyboard.badge.ellipsis.fill",
            "computermouse.fill", "magicmouse.fill", "trackpad.fill",
            "printer.fill", "scanner.fill", "faxmachine.fill",
            "camera.fill", "camera.circle.fill", "camera.shutter.button.fill",
            "camera.badge.ellipsis", "camera.on.rectangle.fill", "camera.aperture"
        ]),
        
        // MARK: - Ulaşım
        IconCategory(name: "category.icons.transport", icons: [
            "car.fill", "car.circle.fill", "car.2.fill", "car.side.fill",
            "car.side.front.open.fill", "car.side.rear.open.fill",
            "car.side.lock.fill", "car.side.lock.open.fill",
            "car.front.waves.up.fill", "car.front.waves.down.fill",
            "car.rear.fill", "car.rear.waves.up.fill",
            "bolt.car.fill", "bolt.car.circle.fill",
            "car.ferry.fill", "bus.fill", "bus.doubledecker.fill",
            "tram.fill", "tram.circle.fill", "tram.fill.tunnel",
            "cablecar.fill", "lightrail.fill", "ferry.fill",
            "airplane", "airplane.circle.fill", "airplane.departure", "airplane.arrival",
            "sailboat.fill", "sailboat.circle.fill", "surfboard.fill",
            "bicycle", "bicycle.circle.fill", "scooter",
            "figure.outdoor.cycle", "motorcycle.fill", "parkingsign",
            "parkingsign.circle.fill", "fuelpump.fill", "fuelpump.circle.fill",
            "fuelpump.exclamationmark.fill",
            "ev.charger.fill", "ev.charger.exclamationmark.fill",
            "steeringwheel.fill", "steeringwheel.badge.exclamationmark",
            "road.lanes", "road.lanes.curved.left", "road.lanes.curved.right",
            "engine.combustion.fill", "oilcan.fill",
            "suv.side.fill", "truck.box.fill", "box.truck.fill",
            "shippingbox.fill", "shippingbox.circle.fill",
            "train.side.front.car", "train.side.middle.car", "train.side.rear.car"
        ]),
        
        // MARK: - Mekanlar
        IconCategory(name: "category.icons.places", icons: [
            "house.fill", "house.circle.fill", "house.and.flag.fill",
            "house.lodge.fill", "house.lodge.circle.fill",
            "music.note.house.fill", "play.house.fill",
            "building.fill", "building.2.fill", "building.2.crop.circle.fill",
            "building.columns.fill", "building.columns.circle.fill",
            "bank.fill", "storefront.fill", "storefront.circle.fill",
            "tent.fill", "tent.circle.fill", "tent.2.fill", "tent.2.circle.fill",
            "beach.umbrella.fill", "umbrella.fill", "umbrella.percent.fill",
            "mountain.2.fill", "mountain.2.circle.fill",
            "globe", "globe.americas.fill", "globe.europe.africa.fill",
            "globe.asia.australia.fill", "globe.central.south.asia.fill",
            "globe.badge.chevron.backward", "globe.desk.fill",
            "map.fill", "map.circle.fill", "mappin", "mappin.circle.fill",
            "mappin.square.fill", "mappin.slash", "mappin.and.ellipse",
            "location.fill", "location.circle.fill", "location.square.fill",
            "location.north.fill", "location.north.circle.fill",
            "location.slash.fill", "location.viewfinder", "sensor.fill",
            "signpost.left.fill", "signpost.right.fill",
            "signpost.right.and.left.fill", "safari.fill"
        ]),
        
        // MARK: - İş & Ofis
        IconCategory(name: "category.icons.work", icons: [
            "briefcase.fill", "briefcase.circle.fill",
            "suitcase.fill", "suitcase.cart.fill",
            "case.fill", "latch.2.case.fill", "cross.case.fill",
            "suitcase.rolling.fill", "backpack.fill", "backpack.circle.fill",
            "studentdesk", "graduationcap.fill", "graduationcap.circle.fill",
            "doc.on.clipboard.fill", "list.clipboard.fill", "list.bullet.clipboard.fill",
            "chart.bar.fill", "chart.pie.fill", "chart.bar.doc.horizontal.fill",
            "chart.line.uptrend.xyaxis", "chart.line.uptrend.xyaxis.circle.fill",
            "chart.xyaxis.line", "chart.line.downtrend.xyaxis",
            "chart.line.flattrend.xyaxis", "chart.bar.xaxis",
            "target", "calendar", "calendar.circle.fill", "calendar.badge.plus",
            "calendar.badge.minus", "calendar.badge.clock", "calendar.badge.exclamationmark",
            "calendar.badge.checkmark",
            "clock.fill", "clock.circle.fill", "clock.badge.checkmark.fill",
            "clock.badge.exclamationmark.fill", "clock.arrow.circlepath",
            "deskclock.fill", "alarm.fill", "alarm.waves.left.and.right.fill",
            "stopwatch.fill", "timer", "timer.circle.fill",
            "hourglass", "hourglass.circle.fill", "hourglass.tophalf.filled",
            "hourglass.bottomhalf.filled", "hourglass.badge.plus",
            "pencil", "pencil.circle.fill", "pencil.slash",
            "pencil.and.outline", "pencil.and.ruler.fill",
            "highlighter", "lasso", "lasso.badge.sparkles",
            "scissors", "paintbrush.fill", "paintbrush.pointed.fill", "paintpalette.fill",
            "ruler.fill", "level.fill", "wrench.fill", "wrench.and.screwdriver.fill",
            "wrench.adjustable.fill", "hammer.fill", "hammer.circle.fill",
            "screwdriver.fill", "eyedropper", "eyedropper.halffull",
            "wand.and.rays", "wand.and.stars", "wand.and.rays.inverse"
        ]),
        
        // MARK: - Sağlık
        IconCategory(name: "category.icons.health", icons: [
            "heart.fill", "heart.circle.fill", "heart.square.fill",
            "heart.slash.fill", "heart.slash.circle.fill",
            "heart.text.square.fill", "bolt.heart.fill",
            "heart.rectangle.fill", "arrow.up.heart.fill", "arrow.down.heart.fill",
            "cross.fill", "cross.circle.fill", "cross.vial.fill",
            "cross.case.fill", "cross.case.circle.fill",
            "pills.fill", "pills.circle.fill", "pill.fill", "pill.circle.fill",
            "capsule.fill", "syringe.fill", "bandage.fill",
            "ivfluid.bag.fill", "medical.thermometer.fill",
            "staroflife.fill", "staroflife.circle.fill",
            "stethoscope", "stethoscope.circle.fill",
            "bed.double.fill", "bed.double.circle.fill",
            "lungs.fill", "lungs.circle.fill", "brain.fill", "brain.head.profile.fill",
            "eye.fill", "eye.circle.fill", "eye.slash.fill", "eye.slash.circle.fill",
            "eye.trianglebadge.exclamationmark.fill",
            "ear.fill", "ear.badge.checkmark", "ear.badge.waveform",
            "ear.trianglebadge.exclamationmark", "ear.and.waveform",
            "hand.raised.fill", "hand.raised.circle.fill", "hand.raised.square.fill",
            "hand.raised.slash.fill",
            "hand.thumbsup.fill", "hand.thumbsup.circle.fill",
            "hand.thumbsdown.fill", "hand.thumbsdown.circle.fill",
            "hand.point.up.fill", "hand.point.up.left.fill",
            "hand.point.down.fill", "hand.point.left.fill", "hand.point.right.fill",
            "hand.draw.fill", "hand.tap.fill", "hand.raised.fingers.spread.fill",
            "hands.clap.fill", "hands.sparkles.fill", "hand.wave.fill",
            "dumbbell.fill", "figure.strengthtraining.traditional",
            "waveform.path.ecg", "waveform.path.ecg.rectangle.fill",
            "waveform", "waveform.circle.fill",
            "facemask.fill", "allergens.fill", "testtube.2"
        ]),
        
        // MARK: - Yiyecek & İçecek
        IconCategory(name: "category.icons.food", icons: [
            "fork.knife", "fork.knife.circle.fill",
            "takeoutbag.and.cup.and.straw.fill",
            "cup.and.saucer.fill", "mug.fill", "wineglass.fill", "waterbottle.fill",
            "birthday.cake.fill", "carrot.fill", "leaf.fill",
            "fish.fill", "fish.circle.fill", "frying.pan.fill", "popcorn.fill",
            "refrigerator.fill", "oven.fill", "microwave.fill",
            "stove.fill", "sink.fill", "dishwasher.fill", "washer.fill",
            "dryer.fill", "dial.low.fill", "dial.medium.fill", "dial.high.fill"
        ]),
        
        // MARK: - Eğlence
        IconCategory(name: "category.icons.entertainment", icons: [
            "play.fill", "play.circle.fill", "play.square.fill", "play.rectangle.fill",
            "pause.fill", "pause.circle.fill", "pause.rectangle.fill",
            "stop.fill", "stop.circle.fill", "record.circle.fill",
            "playpause.fill", "playpause.circle.fill",
            "backward.fill", "backward.circle.fill", "backward.end.fill",
            "forward.fill", "forward.circle.fill", "forward.end.fill",
            "backward.frame.fill", "forward.frame.fill",
            "shuffle", "shuffle.circle.fill", "repeat", "repeat.circle.fill",
            "repeat.1", "repeat.1.circle.fill", "infinity", "infinity.circle.fill",
            "film.fill", "film.circle.fill", "film.stack.fill",
            "video.fill", "video.circle.fill", "video.slash.fill",
            "music.note", "music.note.list", "music.quarternote.3",
            "music.mic", "music.mic.circle.fill",
            "guitars.fill", "pianokeys", "pianokeys.inverse",
            "tuningfork", "dial.fill",
            "theatermasks.fill", "theatermasks.circle.fill",
            "ticket.fill", "ticket.circle.fill",
            "puzzlepiece.fill", "puzzlepiece.extension.fill",
            "dice.fill", "die.face.1.fill", "die.face.2.fill", "die.face.3.fill",
            "die.face.4.fill", "die.face.5.fill", "die.face.6.fill",
            "gamecontroller.fill", "arcade.stick", "arcade.stick.console.fill",
            "paintbrush.fill", "paintbrush.pointed.fill", "paintpalette.fill",
            "photo.fill", "photo.circle.fill", "photo.fill.on.rectangle.fill",
            "photo.stack.fill", "rectangle.stack.fill", "rectangle.on.rectangle.fill",
            "sparkles.tv.fill", "play.tv.fill",
            "camera.fill", "camera.circle.fill", "camera.on.rectangle.fill",
            "livephoto", "livephoto.play", "livephoto.badge.automatic"
        ]),
        
        // MARK: - Eğitim
        IconCategory(name: "category.icons.education", icons: [
            "graduationcap.fill", "graduationcap.circle.fill",
            "book.fill", "book.circle.fill", "book.closed.fill", "book.closed.circle.fill",
            "books.vertical.fill", "books.vertical.circle.fill",
            "book.pages.fill", "text.book.closed.fill",
            "character.book.closed.fill", "menucard.fill",
            "magazine.fill", "newspaper.fill", "newspaper.circle.fill",
            "studentdesk", "backpack.fill", "backpack.circle.fill",
            "pencil.and.ruler.fill", "ruler.fill",
            "brain.head.profile.fill", "brain.fill",
            "lightbulb.fill", "lightbulb.circle.fill", "lightbulb.max.fill",
            "questionmark.circle.fill", "exclamationmark.circle.fill",
            "info.circle.fill", "info.bubble.fill",
            "number.circle.fill", "number.square.fill",
            "a.circle.fill", "a.square.fill", "b.circle.fill", "b.square.fill",
            "c.circle.fill", "c.square.fill", "textformat.abc",
            "textformat.size", "textformat.superscript", "textformat.subscript",
            "function", "fx", "sum", "percent", "plusminus",
            "x.squareroot", "divide.circle.fill", "multiply.circle.fill",
            "minus.circle.fill", "plus.circle.fill", "equal.circle.fill",
            "lessthan.circle.fill", "greaterthan.circle.fill",
            "globe", "globe.americas.fill", "globe.europe.africa.fill"
        ]),
        
        // MARK: - Teknoloji
        IconCategory(name: "category.icons.tech", icons: [
            "cpu.fill", "memorychip.fill", "opticaldisc.fill",
            "internaldrive.fill", "externaldrive.fill", "server.rack",
            "network", "network.badge.shield.half.filled",
            "wifi", "wifi.circle.fill", "wifi.square.fill",
            "wifi.exclamationmark", "wifi.slash",
            "antenna.radiowaves.left.and.right", "antenna.radiowaves.left.and.right.circle.fill",
            "antenna.radiowaves.left.and.right.slash",
            "dot.radiowaves.left.and.right", "dot.radiowaves.right",
            "dot.radiowaves.forward.fill", "wave.3.left", "wave.3.right",
            "wave.3.left.circle.fill", "wave.3.right.circle.fill",
            "bolt.fill", "bolt.circle.fill", "bolt.square.fill",
            "bolt.slash.fill", "bolt.slash.circle.fill",
            "bolt.batteryblock.fill", "bolt.badge.checkmark.fill",
            "battery.100percent", "battery.100percent.circle.fill",
            "battery.75percent", "battery.50percent", "battery.25percent",
            "battery.0percent", "battery.100percent.bolt",
            "power.circle.fill", "power.dotted", "powerplug.fill",
            "terminal.fill", "chevron.left.forwardslash.chevron.right",
            "curlybraces", "curlybraces.square.fill",
            "parentheses", "ellipsis.curlybraces",
            "gear", "gearshape.fill", "gearshape.circle.fill",
            "gearshape.2.fill", "gearshape.arrow.triangle.2.circlepath",
            "wrench.fill", "wrench.and.screwdriver.fill", "wrench.adjustable.fill",
            "hammer.fill", "screwdriver.fill",
            "qrcode", "qrcode.viewfinder", "barcode", "barcode.viewfinder",
            "link", "link.circle.fill", "link.badge.plus",
            "personalhotspot", "personalhotspot.circle.fill",
            "atom", "scalemass.fill", "angle", "compass.drawing",
            "testtube.2", "flask.fill", "aqi.low", "aqi.medium", "aqi.high"
        ]),
        
        // MARK: - Semboller & Şekiller
        IconCategory(name: "category.icons.symbols", icons: [
            "star.fill", "star.circle.fill", "star.square.fill",
            "star.slash.fill", "star.leadinghalf.filled", "star.bubble.fill",
            "heart.fill", "heart.circle.fill", "heart.square.fill",
            "heart.slash.fill", "heart.slash.circle.fill",
            "circle.fill", "circle.circle.fill", "circle.slash.fill",
            "circle.lefthalf.filled", "circle.righthalf.filled",
            "circle.tophalf.filled", "circle.bottomhalf.filled",
            "circle.inset.filled", "circle.dashed",
            "square.fill", "square.circle.fill", "square.slash.fill",
            "square.lefthalf.filled", "square.righthalf.filled",
            "square.inset.filled", "square.dashed", "square.split.2x1.fill",
            "square.split.2x2.fill", "square.split.1x2.fill",
            "triangle.fill", "triangle.circle.fill",
            "triangle.lefthalf.filled", "triangle.righthalf.filled",
            "diamond.fill", "diamond.circle.fill",
            "diamond.lefthalf.filled", "diamond.righthalf.filled",
            "pentagon.fill", "pentagon.lefthalf.filled", "pentagon.righthalf.filled",
            "hexagon.fill", "hexagon.lefthalf.filled", "hexagon.righthalf.filled",
            "octagon.fill", "octagon.lefthalf.filled", "octagon.righthalf.filled",
            "oval.fill", "oval.lefthalf.filled", "oval.righthalf.filled",
            "capsule.fill", "capsule.lefthalf.filled", "capsule.righthalf.filled",
            "seal.fill", "checkmark.seal.fill", "xmark.seal.fill",
            "exclamationmark.triangle.fill", "drop.fill", "drop.circle.fill",
            "play.fill", "play.circle.fill", "pause.fill", "stop.fill",
            "plus.circle.fill", "minus.circle.fill", "multiply.circle.fill",
            "divide.circle.fill", "equal.circle.fill",
            "checkmark.circle.fill", "xmark.circle.fill",
            "exclamationmark.circle.fill", "questionmark.circle.fill",
            "info.circle.fill", "at.circle.fill", "number.circle.fill",
            "dollarsign.circle.fill", "eurosign.circle.fill",
            "sterlingsign.circle.fill", "yensign.circle.fill",
            "turkishlirasign.circle.fill", "bitcoinsign.circle.fill",
            "arrow.up.circle.fill", "arrow.down.circle.fill",
            "arrow.left.circle.fill", "arrow.right.circle.fill",
            "arrow.uturn.left.circle.fill", "arrow.uturn.right.circle.fill",
            "arrow.clockwise.circle.fill", "arrow.counterclockwise.circle.fill",
            "arrowshape.turn.up.left.fill", "arrowshape.turn.up.right.fill"
        ]),
        
        // MARK: - Güvenlik
        IconCategory(name: "category.icons.security", icons: [
            "lock.fill", "lock.circle.fill", "lock.square.fill",
            "lock.square.stack.fill", "lock.rectangle.fill", "lock.rectangle.stack.fill",
            "lock.slash.fill", "lock.open.fill", "lock.rotation",
            "lock.rotation.open", "lock.shield.fill", "lock.trianglebadge.exclamationmark.fill",
            "key.fill", "key.horizontal.fill", "key.icloud.fill",
            "key.radiowaves.forward.fill", "key.viewfinder", "key.slash.fill",
            "shield.fill", "shield.lefthalf.filled", "shield.righthalf.filled",
            "shield.slash.fill", "shield.lefthalf.filled.slash",
            "shield.checkered", "checkmark.shield.fill",
            "xmark.shield.fill", "exclamationmark.shield.fill",
            "shield.lefthalf.filled.badge.checkmark",
            "touchid", "faceid", "opticid.fill",
            "person.badge.key.fill", "person.badge.shield.checkmark.fill",
            "hand.raised.fill", "hand.raised.slash.fill",
            "eye.slash.fill", "eye.trianglebadge.exclamationmark.fill",
            "exclamationmark.lock.fill", "exclamationmark.triangle.fill"
        ]),
        
        // MARK: - Medya Kontrolleri
        IconCategory(name: "category.icons.media", icons: [
            "play.fill", "play.circle.fill", "play.square.fill", "play.rectangle.fill",
            "pause.fill", "pause.circle.fill", "pause.rectangle.fill",
            "stop.fill", "stop.circle.fill", "record.circle.fill",
            "playpause.fill", "playpause.circle.fill",
            "backward.fill", "backward.circle.fill", "backward.end.fill",
            "backward.end.alt.fill", "backward.frame.fill",
            "forward.fill", "forward.circle.fill", "forward.end.fill",
            "forward.end.alt.fill", "forward.frame.fill",
            "shuffle", "shuffle.circle.fill", "repeat", "repeat.circle.fill",
            "repeat.1", "repeat.1.circle.fill", "infinity", "infinity.circle.fill",
            "megaphone.fill", "speaker.fill", "speaker.circle.fill",
            "speaker.slash.fill", "speaker.slash.circle.fill",
            "speaker.wave.1.fill", "speaker.wave.2.fill", "speaker.wave.3.fill",
            "speaker.zzz.fill", "speaker.badge.exclamationmark.fill",
            "speaker.plus.fill", "speaker.minus.fill",
            "music.note", "music.note.list", "music.quarternote.3",
            "music.mic", "music.mic.circle.fill",
            "goforward", "gobackward", "goforward.5", "gobackward.5",
            "goforward.10", "gobackward.10", "goforward.15", "gobackward.15",
            "goforward.30", "gobackward.30", "goforward.45", "gobackward.45",
            "goforward.60", "gobackward.60",
            "mount.fill", "eject.fill", "eject.circle.fill"
        ]),
        
        // MARK: - Bayraklar & Rozetler
        IconCategory(name: "category.icons.badges", icons: [
            "flag.fill", "flag.circle.fill", "flag.square.fill",
            "flag.slash.fill", "flag.slash.circle.fill",
            "flag.badge.ellipsis.fill", "flag.2.crossed.fill",
            "flag.filled.and.flag.crossed", "flag.checkered", "flag.checkered.2.crossed",
            "rosette", "seal.fill", "checkmark.seal.fill", "xmark.seal.fill",
            "shield.fill", "shield.lefthalf.filled", "shield.righthalf.filled",
            "shield.slash.fill", "checkmark.shield.fill", "xmark.shield.fill",
            "crown.fill", "comb.fill", "peacesign", "atom", "scalemass.fill",
            "gift.fill", "gift.circle.fill",
            "app.badge.fill", "app.badge.checkmark.fill",
            "app.dashed", "appclip", "app.fill",
            "square.grid.2x2.fill", "square.grid.3x2.fill",
            "square.grid.3x3.fill", "square.grid.4x3.fill",
            "circle.grid.2x2.fill", "circle.grid.3x3.fill",
            "circle.hexagongrid.fill", "circle.hexagonpath.fill",
            "rectangle.grid.2x2.fill", "rectangle.grid.3x2.fill",
            "rectangle.grid.1x2.fill", "square.stack.3d.up.fill"
        ])
    ]
}