jquery = require("jquery")
ko = require("knockout")
common = require("./common.coffee")

vm =
    contactInfo:
        name: ko.observable("")
        phone: ko.observable("")
        addr: ko.observable("")
    is_all_checked: ko.observable(false)

$settleBtn = jquery(".settle-btn")
$contactInfoConfirm = jquery(".contact-info-confirm")
$contactInfoChange = jquery(".contact-info-change")
$confirmBtn = jquery(".confirm-btn")
$changeBtn = jquery(".change-btn")
$cancelBtn = jquery(".cancel-btn")
$saveBtn = jquery(".save-btn")
$mask = jquery('.mask')
originalContactInfo = {}

window.onload = ->
    common.init()
    getCartObjs()
    getContactInfo()
    initBtns()

getCartObjs = ->
    jquery.ajax
        url: common.url + "/cart"
        type: "POST"
        data:
            csrf_token: common.token
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
            originalContactInfo = res.data
            bindContactInfo res.data if res.code is 0

initBtns = ->
    $mask.click (e)->
        d = e.target
        while  d != null and d.className != 'mask-box-container'
            d = d.parentNode
        unless d != null and d.className == 'mask-box-container'
            $cancelBtn.click()
            $contactInfoChange.hide()
            $contactInfoConfirm.hide()
            common.hideMask()

    $settleBtn.click ->
        if vm.checkedProductsLength() < 1
            common.notify '请选择商品'
        else
            common.showMask()
            $contactInfoConfirm.show()

    $cancelBtn.click ->
        vm.contactInfo.name(originalContactInfo.name)
        vm.contactInfo.phone(originalContactInfo.phone)
        vm.contactInfo.addr(originalContactInfo.addr)
        $contactInfoChange.hide()
        $contactInfoConfirm.show()

    $saveBtn.click ->
        originalContactInfo.name = vm.contactInfo.name()
        originalContactInfo.phone = vm.contactInfo.phone()
        originalContactInfo.addr = vm.contactInfo.addr()
        $contactInfoChange.hide()
        $contactInfoConfirm.show()

    $changeBtn.click ->
        $contactInfoConfirm.hide()
        $contactInfoChange.show()

    settleStrategy =
        "0": "成功下单"
        "1": "error: 无效的参数"
        "-2": "error: 存在无效商品，请刷新页面后再试"

    $confirmBtn.click ->
        if vm.checkedProductsLength() < 1
            common.notify '请选择商品'
        else
            jquery.ajax
                url: common.url + "/order/create"
                type: "POST"
                data:
                    csrf_token: common.token
                    product_ids: getCheckedProductIds()
                    name: vm.contactInfo.name()
                    phone: vm.contactInfo.phone()
                    addr: vm.contactInfo.addr()
                success: (res) =>
                    res = JSON.parse(res)
                    common.notify(settleStrategy[res.code])

bindCartObjs = (objs)->
    for obj in objs
        # let necessary property of obj observable
        obj['is_checked'] = ko.observable(false)
        obj.quantity = ko.observable(obj.quantity)
        injectProperties obj
    vm.cartObjs = ko.observableArray(objs)
    ko.applyBindings(vm)

injectProperties = (obj)->
    obj.setQuantity = ->
        quantity = parseInt(@quantity())
        if quantity and quantity > 0
            @quantity(quantity)
        else
            @quantity(1)
            common.notify("请输入正整数");
            return
        jquery.ajax
            url: common.url + '/cart/set_quantity'
            type: "POST"
            data:
                csrf_token: common.token
                product_id: @product_id
                quantity: @quantity()

    obj.validStatus = -> @is_valid ? '' : 'unvalid'
    obj.removeSelf = -> @deleteHandler('/cart/delete')
    obj.add = -> @quantityHandler('/cart/add')
    obj.reduce = -> @quantityHandler('/cart/sub')
    obj.quantityHandler = quantityHandler
    obj.deleteHandler = deleteHandler
    obj.totalPrice = ko.pureComputed ->
        @quantity() * @price
    , obj
    obj.formattedPrice = ko.pureComputed ->
        "￥" + @totalPrice()
    , obj

deleteHandler = (suffix) ->
    jquery.ajax
        url: common.url + suffix
        type: "POST"
        data:
            _crsf_token: common.token
            product_id: @product_id
        success: (res) =>
            res = JSON.parse(res)
            vm.cartObjs.remove @

quantityHandler = (suffix)->
    jquery.ajax
        url: common.url + suffix
        type: "POST"
        data:
            csrf_token: common.token
            product_id: @product_id
        success: (res)=>
            res = JSON.parse(res)
            @quantity(res.data) if res.code is 0 and res.data > 0

bindContactInfo = (info)->
    props = ['name', 'phone', 'addr']
    for prop in props
        vm.contactInfo[prop](info[prop])

getCheckedProducts = ->
    vm.cartObjs().filter (cart_obj)->
        cart_obj if cart_obj.is_checked() and cart_obj.is_valid

getCheckedProductIds = ->
    productIdsArray = getCheckedProducts().map (valid_cart_obj) ->
        valid_cart_obj.product_id
    return productIdsArray.join(',')

vm.deleteCheckedProducts = ->
    checked_cart_obj.removeSelf() for checked_cart_obj in getCheckedProducts()


vm.checkAllProducts = ->
    vm.is_all_checked(!vm.is_all_checked())
    cart_obj.is_checked(vm.is_all_checked()) for cart_obj in vm.cartObjs()

vm.deleteInvalidProducts = ->
    cart_obj.removeSelf() for cart_obj in vm.cartObjs() when cart_obj.is_valid

vm.checkedProductsLength = ko.pureComputed ->
    getCheckedProducts().length

vm.checkedProductsTotal = ko.pureComputed ->
    total = 0
    total += checkedProduct.totalPrice() for checkedProduct in getCheckedProducts()
    return "￥" + total

vm.cartObjsLength = ko.pureComputed ->
    vm.cartObjs().length
