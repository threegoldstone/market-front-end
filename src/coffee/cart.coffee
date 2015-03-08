jquery = require("jquery")
ko = require("knockout")
common = require("./common.coffee")

vm =
    contactInfo:
        name: ko.observable("")
        phone: ko.observable("")
        addr: ko.observable("")

$settleBtn = jquery(".settle-btn")
$contactInfo = jquery(".contact-info")
$confirmBtn = jquery(".confirm-btn")

window.onload = ->
    common.init()
    getCartObjs()
    getContactInfo()
    initBtns()
    console.log vm

getCartObjs = ->
    jquery.ajax
        url: common.url + "/cart/goods"
        type: "POST"
        data:
            crsf_token: common.token
        success: (res)->
            res = JSON.parse(res)
            if res.code is 0
                bindCartObjs res.data

getContactInfo = ->
    jquery.ajax
        url: common.url + "/user/contact_info"
        type: "POST"
        data:
            csrf_token: common.token
        success: (res)->
            res = JSON.parse(res)
            bindContactInfo res.data if res.code is 0

initBtns = ->
    $settleBtn.click ->
        $contactInfo.show()
    $confirmBtn.click ->
        jquery.ajax
            url: common.url + "/order/create"
            type: "POST"
            data:
                csrf_token: common.token
                product_ids: getCheckedProductIds()
                name: vm.contactInfo.name()
                phone: vm.contactInfo.phone()
                addr: vm.contactInfo.addr()

bindCartObjs = (objs)->
    for obj in objs
        # let necessary property of obj observable
        obj['is_checked'] = ko.observable(false)
        obj['quantity'] = ko.observable(obj.quantity)
        injectProperties obj
    vm.cartObjs = ko.observableArray(objs)
    ko.applyBindings(vm)

injectProperties = (obj)->
    obj.validStatus = -> @is_valid ? '' : 'unvalid'
    obj.removeSelf = ->
        # send delete ajax
        vm.cartObjs.remove @
    obj.add = -> @quantityHandler('/cart/add')
    obj.reduce = -> @quantityHandler('/cart/sub') 
    obj.quantityHandler = quantityHandler
    obj.totalPrice = ko.pureComputed ->
        @quantity() * @price
    , obj

quantityHandler = (suffix)->
    jquery.ajax
        url: common.url + suffix
        type: "POST"
        data:
            csrf_token: common.token            
            product_id: @product_id
        success: (res)=>
            res = JSON.parse(res)
            @quantity(res.data) if res.code is 0

bindContactInfo = (info)->
    props = ['name', 'phone', 'addr']
    for prop in props
        vm.contactInfo[prop](info[prop])

getCheckedProductIds = ->
    vm.cartObjs.filter (element)->
        element.is_checked is true