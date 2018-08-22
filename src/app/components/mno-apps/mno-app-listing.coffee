angular.module 'mnoEnterpriseAngular'
  .component('mnoAppListing', {
    templateUrl: 'app/components/mno-apps/mno-app-listing.html',
    bindings: {
      isPublic: '@'
    }
    controller: ($scope, toastr, MnoeOrganizations, MnoeMarketplace, MnoeConfig) ->
      vm = this

      #====================================
      # Initialization
      #====================================
      vm.$onInit = ->
        vm.publicPage = vm.isPublic == "true"
        vm.isLoading = true
        vm.selectedCategory = ''
        vm.searchTerm = ''
        vm.filteredApps = []
        vm.isMarketplaceCompare = MnoeConfig.isMarketplaceComparisonEnabled()
        vm.showCompare = false
        vm.nbAppsToCompare = 0
        vm.appState = if vm.publicPage then "public.product" else "home.marketplace.app"
        vm.displayAll = {label: "", active: 'active'}
        vm.selectedPublicCategory = vm.displayAll
        vm.initialize()
      #====================================
      # Scope Management
      #====================================

      # Filter apps by name or category
      vm.onSearchChange = () ->
        vm.selectedCategory = ''
        term = vm.searchTerm.toLowerCase()
        vm.filteredApps = (app for app in vm.apps when (app.name && app.name.toLowerCase().indexOf(term) isnt -1) or
        _.some(app.tags, (tag) -> tag.toLowerCase().indexOf(term) isnt -1) or
        (app.tiny_description && app.tiny_description.toLowerCase().indexOf(term) isnt -1) or
        (app.description && app.description.toLowerCase().indexOf(term) isnt -1))

      vm.onCategoryChange = () ->
        vm.searchTerm = ''
        vm.currentSelectedCategory = if vm.publicPage then vm.selectedPublicCategory.label else vm.selectedCategory
        if (vm.currentSelectedCategory?.length > 0)
          vm.filteredApps = _.filter(vm.apps, (app) -> _.includes(app.categories, vm.currentSelectedCategory))
        else
          vm.filteredApps = vm.apps

      vm.resetCategory = (category) ->
        vm.selectedPublicCategory.active = ''
        category.active = 'active'
        vm.selectedPublicCategory = category

      # Cancel comparison
      vm.cancelComparison = ->
        vm.showCompare = false

      # Uncheck all checkboxes
      vm.uncheckAllApps = () ->
        angular.forEach(vm.apps, (items) ->
          items.toCompare = false
        )

      # Toggle compare block
      vm.enableComparison = ->
        vm.nbAppsToCompare = 0
        vm.uncheckAllApps()
        vm.showCompare = true

      vm.toggleAppToCompare = (app) ->
        selected = app.toCompare
        if selected && vm.nbAppsToCompare >= 4
          toastr.info("mno_enterprise.templates.dashboard.marketplace.index.toastr.error")
          app.toCompare = false
        else
          vm.nbAppsToCompare += if selected then 1 else (-1)

      vm.canBeCompared = ->
        return vm.nbAppsToCompare <= 4 && vm.nbAppsToCompare >=2

      vm.initialize = ->
        vm.isLoading = true
        MnoeMarketplace.getApps().then(
          (response) ->
            # Remove restangular decoration
            response = response.plain()

            vm.categories = response.categories
            vm.apps = _.sortByAll(response.apps, ['rank', (a) -> a.name?.toLowerCase()])
            if vm.publicPage
              vm.apps = _.filter(vm.apps, (app) -> _.includes(MnoeConfig.publicApplications(), app.nid))
              categoriesWithProduct = _.uniq(_.flatten(_.map(vm.apps, (app) -> app.categories)))
              vm.publicCategories = _.map(categoriesWithProduct, (c) -> {label: c, active: ''})
            vm.filteredApps = vm.apps
      ).finally(-> vm.isLoading = false)

      $scope.$watch MnoeOrganizations.getSelectedId, (val) ->
        if val?
          vm.initialize()

      return
    })
