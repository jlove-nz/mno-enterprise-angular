angular.module 'mnoEnterpriseAngular'
  .controller('ProvisioningOrderCtrl', ($scope, $q, $state, $stateParams, MnoeOrganizations, MnoeMarketplace, MnoeProvisioning, MnoeConfig, ProvisioningHelper, toastr) ->

    vm = this
    vm.isLoading = true
    vm.subscription = MnoeProvisioning.getCachedSubscription()
    vm.pricedPlan = ProvisioningHelper.pricedPlan
    urlParams = {
      productId: $stateParams.productId,
      subscriptionId: $stateParams.subscriptionId,
      editAction: $stateParams.editAction
    }

    fetchSubscription = () ->
      orgPromise = MnoeOrganizations.get()
      initPromise = MnoeProvisioning.initSubscription({productId: $stateParams.productId, subscriptionId: $stateParams.subscriptionId})

      $q.all({organization: orgPromise, subscription: initPromise}).then(
        (response) ->
          vm.orgCurrency = response.organization.organization?.billing_currency || MnoeConfig.marketplaceCurrency()
          vm.subscription = response.subscription
        )

    filterCurrencies = (productPricings) ->
      _.filter(vm.subscription.product.pricing_plans,
        (pp) -> !vm.pricedPlan(pp) || _.some(pp.prices, (p) -> p.currency == vm.orgCurrency)
      )

    fetchProduct = () ->
      # When in edit mode, we will be getting the product ID from the subscription, otherwise from the url.
      vm.productId = vm.subscription.product?.id || $stateParams.productId
      MnoeMarketplace.getProduct(vm.productId, { editAction: $stateParams.editAction }).then(
        (response) ->
          vm.subscription.product = response

          # Filters the pricing plans not containing current currency
          vm.subscription.product.pricing_plans = filterCurrencies(vm.subscription.product.product_pricings)
          MnoeProvisioning.setSubscription(vm.subscription)
        )

    fetchCustomSchema = () ->
      MnoeMarketplace.fetchCustomSchema(vm.productId, { editAction: $stateParams.editAction }).then((response) ->
        # Some products have custom schemas, whereas others do not.
        vm.subscription.product.custom_schema = response
        )

    if _.isEmpty(vm.subscription)
      fetchSubscription()
        .then(fetchProduct)
        .then(fetchCustomSchema)
        .then(() -> vm.next(vm.subscription) if vm.skipPriceSelection(vm.subscription.product))
        .catch((error) ->
          toastr.error('mnoe_admin_panel.dashboard.provisioning.subscriptions.product_error')
          $state.go('home.subscriptions')
        )
        .finally(() -> vm.isLoading = false)
    else
      vm.isLoading = false

    vm.select_plan = (pricingPlan)->
      vm.subscription.product_pricing = pricingPlan
      vm.subscription.max_licenses ||= 1 if vm.subscription.product_pricing.license_based

    vm.next = (subscription) ->
      MnoeProvisioning.setSubscription(subscription)
      if vm.subscription.product.custom_schema?
        $state.go('home.provisioning.additional_details', urlParams)
      else
        $state.go('home.provisioning.confirm', urlParams)

    vm.subscriptionPlanText = switch $stateParams.editAction.toLowerCase()
      when 'new'
        'mno_enterprise.templates.dashboard.provisioning.order.new_title'
      when 'change'
        'mno_enterprise.templates.dashboard.provisioning.order.change_title'

    vm.selectPlan = (pricingPlan)->
      vm.subscription.product_pricing = pricingPlan
      vm.subscription.max_licenses ||= 1 if vm.subscription.product_pricing.license_based

    vm.skipPriceSelection = (product) ->
      product.product_type == 'application' && (!product.single_billing_enabled || !product.billed_locally)

    # Delete the cached subscription when we are leaving the subscription workflow.
    $scope.$on('$stateChangeStart', (event, toState) ->
      switch toState.name
        when "home.provisioning.confirm", "home.provisioning.order_summary", "home.provisioning.additional_details"
          null
        else
          MnoeProvisioning.setSubscription({})
    )
    return
  )