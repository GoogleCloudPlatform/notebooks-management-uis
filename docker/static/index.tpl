<!--
 Copyright 2021 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->

<html lang=en xmlns:th="http://www.thymeleaf.org">
<head>
  <title>Notebooks Management Console</title>
  <meta http-equiv="Cache-control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <link rel="stylesheet" href="${relative_path}/third_party/materialize/materialize.min.css">
  <style>
    @font-face {
      font-family: 'Material Icons';
      font-style: normal;
      font-weight: 400;
      src: url(${relative_path}/third_party/material-design-icons/font/MaterialIcons-Regular.ttf); /* For IE6-8 */
      src: local('Material Icons'),
        local('MaterialIcons-Regular'),
        url(${relative_path}/third_party/material-design-icons/font/MaterialIcons-Regular.ttf) format('truetype');
    }
    .material-icons {
      font-family: 'Material Icons';
      font-weight: normal;
      font-style: normal;
      font-size: 24px;  /* Preferred icon size */
      display: inline-block;
      line-height: 1;
      text-transform: none;
      letter-spacing: normal;
      word-wrap: normal;
      white-space: nowrap;
      direction: ltr;

      /* Support for all WebKit browsers. */
      -webkit-font-smoothing: antialiased;
      /* Support for Safari and Chrome. */
      text-rendering: optimizeLegibility;

      /* Support for Firefox. */
      -moz-osx-font-smoothing: grayscale;

      /* Support for IE. */
      font-feature-settings: 'liga';
    }
    /* Override materialize */
    .navbar-fixed {height:48px; background-color: #1a73e8;margin-bottom: 20px;}
    nav, nav .nav-wrapper i, nav a.sidenav-trigger, nav a.sidenav-trigger i {height: 44px;line-height: 44px;}
    .dropdown-content li {min-height: 45px;}
    .dropdown-content li>a, .dropdown-content li>span {color: #000;font-family:Roboto;font-size:15px;font-style:normal;font-weight:400;}
    /* Custom */
    h6{font-family: Roboto;font-size:18px;font-weight: 400;margin:0;padding:0;}
    p{font-family: Roboto;font-size: 13px;font-style: normal;font-weight: 400;height: auto;letter-spacing: normal;line-height: 20px;}
    a.upper_case, a.upper_case:link, a.upper_case:visited {color: #3367d6;cursor: pointer;text-transform: uppercase; font-weight: 500; font-size: 13px;font-family: Roboto;}
    a.upper_case:hover {color: #1C3AA9; background-color:rgba(0, 0, 0, 0.04);}
    .m-no{margin:0 0 0 0;}
    .m-l-s {margin-left:5px;}
    .m-t-s {margin-top:5px;}
    .m-r-s {margin-right:5px;}
    .m-b-s {margin-bottom:5px;}
    table>thead {font-family: Roboto;font-size: 12px;font-style: normal;font-weight: 500;height: 20px;line-height: 20px;}
    table>thead>tr>th {background-color:rgba(0, 0, 0, 0.04);outline-width:0px;padding-bottom:4px;padding-right:8px;padding-top:4px;}
    table>tbody>tr>td{color:rgba(0, 0, 0, 0.66);display:table-cell;font-family:Roboto;font-size:13px;font-weight: 400;height: 50px;left: 0px;letter-spacing: normal;line-height: 20px;}
    [type="checkbox"].filled-in:checked+span:not(.lever):after{border: 2px solid #1a73e8;background-color: #1a73e8;}
    #projects-list tr:hover {background-color:rgba(0,0,0,.04);cursor: pointer;}
  </style>
  <script>
    var GoogleAuth;
    var stateDOMs = {
      ACTIVE: 'check_circle',
      STOPPED: 'stop',
      STOPPING: 'preloader-wrapper',
      STARTING: 'preloader-wrapper',
      PROVISIONING: 'preloader-wrapper',
      UPGRADING: 'preloader-wrapper',
      INITIALIZING: 'preloader-wrapper',
      REGISTERING: 'preloader-wrapper',
      STATE_UNSPECIFIED: 'error',
      DELETED: 'error',
    }
    var URL_VAR_PROJECT_ID = "projectId";
    var stateCheckIntervals = new Object();
    var currentUser = new User();
    var currentGCPContext = new GCPContext();

    function handleClientLoad() {
      // Load the API's client and auth2 modules.
      // Call the initClient function after the modules load.
      gapi.load('client:auth2', initClient);
    }

    function initClient() {
      // Initialize the gapi.client object, which app uses to make API requests.
      // Get API key and client ID from API Console.
      // 'scope' field specifies space-delimited list of access scopes.
      // https://developers.google.com/identity/sign-in/web/reference
      gapi.client.init(config).then(function () {
        GoogleAuth = gapi.auth2.getAuthInstance();

        // Listen for sign-in state changes.
        GoogleAuth.isSignedIn.listen(updateSigninStatus);

        // Handle initial sign-in state. (Determine if user is already signed in.)
        var user = GoogleAuth.currentUser.get();
        setSigninStatus();

        // Call handleAuthClick function when user clicks on "Sign In/Authorize" button.
        $('#sign-in-button').click(function() {handleAuthClick();});
        $('#sign-out-button').click(function() {handleAuthClick();});
        $('#revoke-access-button').click(function() {revokeAccess();});
        $('#list-instances-button').click(function() {handleListInstances();});
        if (getURLVariable(URL_VAR_PROJECT_ID) == "") {
          $('#nav-projects-select').click(function() {handleListProjects()});
        }
        $('#action-instances-start').click(function() {handleStartInstance();});
        $('#action-instances-stop').click(function() {handleStopInstance();});

        // Init other DOM elements.
        $(".dropdown-trigger").dropdown({constrainWidth: false, coverTrigger: false});
        $('.modal').modal();

        // Handle project set in URL
        if (getURLVariable(URL_VAR_PROJECT_ID) != "") {
          $('#nav-projects-select i:first-of-type').hide();
          handleListInstances();
        }
      });
    }

    function handleAuthClick() {
      if (GoogleAuth.isSignedIn.get()) {
        // User is authorized and has clicked "Sign out" button.
        GoogleAuth.signOut();
      } else {
        // User is not signed in. Start Google auth flow.
        GoogleAuth.signIn();
      }
    }

    function revokeAccess() {
      GoogleAuth.disconnect();
    }

    function User() {
      this.name = "";
      this.email = "";
      this.avatar = "";
      this.setUser = function(profile){
        this.name = profile.getName();
        this.email = profile.getEmail();
        this.avatar = profile.getImageUrl();
      }
      this.getName = function() {return this.name;}
      this.getEmail = function() {return this.email;};
      this.getAvatar = function() {return this.avatar;};
    }

    function GCPContext() {
      this.organization = "";
      this.projectId = getURLVariable(URL_VAR_PROJECT_ID);
      this.setOrganization = function(organization) {
        this.organization = organization;
      }
      this.setProjectId = function(pid) {this.projectId = pid;}
      this.getProjectId = function() { return this.projectId; }
    }

    function setSigninStatus() {
      var signedUser = GoogleAuth.currentUser.get();
      var isAuthorized = signedUser.hasGrantedScopes(scopes);
      if (isAuthorized) {
        currentUser.setUser(signedUser.getBasicProfile());
        updateNavProfile();
        $("#body-no-authenticated").hide();
        $("#general-loader").hide();
        if (currentGCPContext.getProjectId() == "") {
          $("#body-no-project").show();
        }
        $('#nav-profile').css('display', 'inline-block');
        $('#nav-projects').css('display', 'inline-block');
        updateProject(currentGCPContext.getProjectId())
      } else {
        $("#body-no-authenticated").show();
        $("#general-loader").hide();
        $("#body-no-project").hide();
        $("#body-content").hide();
        $('#nav-profile').css('display', 'none');
        $('#nav-projects').css('display', 'none');
        updateProject("");
      }
    }

    function updateSigninStatus() {
      setSigninStatus();
    }

    function showPart(partId, loader = false) {
      $('#' + partId).show();
      $('#' + partId + '-loader').hide();
    }

    function hidePart(partId, loader = true) {
      $('#' + partId).hide();
      if (loader) {
        $('#' + partId + '-loader').show();
      }
    }

    function handleListProjects() {
      $('#modal-projects').modal('open');
      hidePart("modal-project-list");
      url = "https://cloudresourcemanager.googleapis.com/v1/projects";
      var request = gapi.client.request({
        'method': 'GET',
        'path': url
      });
      // Execute the API request.
      request.execute(function(response) {
        showPart("modal-project-list");
        addProjectsToDOM(response.projects);
      });
    }

    function handleChooseProject(pid) {
      console.log("User chose project " + pid);
      updateProject(pid);
      handleListInstances()
    }

    function updateProject(pid) {
      select_text = (pid === "") ? "Select a project" : pid;
      currentGCPContext.setProjectId(pid);
      updateDOMProject(select_text);
    }

    function handleListInstances(location = '-') {
      $('#body-no-project').hide();
      $('#body-content').show();
      hidePart('body-results');
      projectId = currentGCPContext.getProjectId()
      parent = "projects/" + projectId + "/locations/" + location;
      url = "https://notebooks.googleapis.com/v1/" + parent + "/instances";
      var request = gapi.client.request({
        'method': 'GET',
        'path': url
      });
      // Execute the API request.
      request.execute(function(response) {
        showPart('body-results');
        addInstancesToDOM(response)
      });
    }

    function handleStartInstance() {
      var selected = [];
      $('#body-results input:checked').each(function() {
        var instanceFullName = $(this).attr('id').replaceAll('_', '/');
        console.log('Starting instance ' + instanceFullName);
        // We add an update here so we don't wait for the API to come back.
        updateDOMState(instanceFullName, 'STARTING');
        var url = "https://notebooks.googleapis.com/v1/" + instanceFullName + ":start";
        var request = gapi.client.request({
          'method': 'POST',
          'path': url
        });
        // Execute the API request.
        request.execute(function(response) {
          stateCheckIntervals[instanceFullName] = setInterval(handleCheckState, 5000, instanceFullName);
        });
      });
    }

    function handleStopInstance() {
      var selected = [];
      $('#body-results input:checked').each(function() {
        var instanceFullName = $(this).attr('id').replaceAll('_', '/');
        console.log('Stopping instance ' + instanceFullName);
        // We add an update here so we don't wait for the API to come back.
        updateDOMState(instanceFullName, 'STOPPING');
        var url = "https://notebooks.googleapis.com/v1/" + instanceFullName + ":stop";
        var request = gapi.client.request({
          'method': 'POST',
          'path': url
        });
        request.execute(function(response) {
          stateCheckIntervals[instanceFullName] = setInterval(handleCheckState, 5000, instanceFullName);
        });
      });
    }

    function handleCheckState(instance) {
      console.log("Checking state for instance " + instance);
      var url = "https://notebooks.googleapis.com/v1/" + instance;
      var request = gapi.client.request({
        'method': 'GET',
        'path': url
      });
      request.execute(function(response) {
        if (response.state == 'STOPPED' || response.state == 'ACTIVE') {
          console.log("Clearing interval for " + instance);
          clearInterval(stateCheckIntervals[instance]);
          delete stateCheckIntervals[instance];
        }
        updateDOMState(instance, response.state);
      });
    }
    // ----------------------
    // Helpers
    // ----------------------
    function getURLVariable(variable) {
      const query = window.location.search.substring(1);
      var vars = query.split('&');
      for (var i = 0; i < vars.length; i++) {
        var pair = vars[i].split('=');
        if (decodeURIComponent(pair[0]) == variable) {
          return decodeURIComponent(pair[1]);
        }
      }
      return "";
    }

    // ----------------------
    // DOM functions
    // ----------------------
    function addProjectsToDOM(projects) {
      $("#projects-list").html("");
      for (let i = 0; i < projects.length; i++) {
        project = projects[i];
        // Row
        let tr_attributes = {
          id: project.projectId,
          class: "modal-close",
        };
        let tr_html = $("<tr>", tr_attributes);
        // Name
        let td_name_html = $("<td>", {class: ""});
        td_name_html.html(project.name);
        // Id
        let td_id_html = $("<td>", {class: ""});
        td_id_html.html(project.projectId);
        // Add to project list. Need to use `data` otherwise
        // the loop remembers only the last project of the loop.
        tr_html.append(td_name_html);
        tr_html.append(td_id_html);
        tr_html.data('savedPid', project.projectId).click(function() {
          handleChooseProject($(this).data('savedPid'));
        });
        $("#projects-list").append(tr_html);
      }
    }

    function updateNavProfile() {
      $("#nav-avatar").attr("src", currentUser.avatar);
      $("#nav-name").html(currentUser.name)
      $("#nav-email").html(currentUser.email)
    }

    function addInstancesToDOM(response, filter = 'user') {
      $("#instances-list").html("")
      if (!response.hasOwnProperty('instances')) {
        let tr_html = $("<tr>", {style: "border-bottom:0;"});
        let td_html = $("<td>", {style: "text-align:center;", colspan: "7"});
        td_html.append('<div><i class="material-icons" style="font-size:100px">blur_on</i></div>');
        td_html.append('<div>No instance found</div>');
        tr_html.append(td_html);
        $("#instances-list").append(tr_html);
        return
      }
      var instances = response.instances;
      var instance;

      for (let i = 0; i < instances.length; i++) {
        instance = instances[i];
        if (filter == 'user'
            && instance.metadata['proxy-user-mail'] !== undefined
            && instance.metadata['proxy-user-mail'] != currentUser.getEmail()) {
          continue;
        }

        partsName = instance.name.split('/')
        partsMachineTypes = instance.machineType.split('/')
        instanceFullNameId = instance.name.replaceAll('/', '_')
        instanceName = partsName[partsName.length - 1]
        instanceZone = partsName[partsName.length - 3]
        instanceType = partsMachineTypes[partsMachineTypes.length - 1]
        // Row
        let tr_attributes = {class: ""}
        let tr_html = $("<tr>", tr_attributes)
        // Checkbox
        //'<label><input type="checkbox" class="filled-in" checked="checked" id=""/><span>Filled in</span></label>'
        let td_cb_html = $("<td>", {style: "text-align:center;"});
        let cb_box_attributes = {
          type: 'checkbox',
          id: instanceFullNameId,
          class: 'filled-in checkbox-blue'
        }
        let cb_label_html = $("<label>", {});
        let cb_span_html = $("<span>", {});
        let cb_box_html = $("<input>", cb_box_attributes);
        cb_label_html.append(cb_box_html);
        cb_label_html.append(cb_span_html);
        td_cb_html.append(cb_label_html)
        // State
        let td_state_html = $("<td>", {class: ""});
        let state_html = buildDOMFromState(instance.name, instance.state);
        td_state_html.append(state_html);
        // Name
        let td_name_html = $("<td>", {class: ""});
        td_name_html.html(instanceName);
        // Open jupyterlab
        let td_lab_html = $("<td>", {});
        let a_lab_attributes = {
          class: "upper_case",
          href: 'http://' + instance.proxyUri,
          target:"_blank"
        };
        let a_lab_html = $("<a>", a_lab_attributes);
        a_lab_html.html("OPEN JUPYTERLAB");
        td_lab_html.append(a_lab_html);
        // Zone
        let td_zone_html = $("<td>", {class: ""});
        td_zone_html.html(instanceZone);
        // Environment
        let td_environment_html = $("<td>", {class: ""});
        td_environment_html.html(instance.metadata.framework);
        // Machine Type
        let td_machine_html = $("<td>", {class: ""});
        td_machine_html.html(instanceType);

        // Put together
        tr_html.append(td_cb_html);
        tr_html.append(td_state_html);
        tr_html.append(td_name_html);
        tr_html.append(td_lab_html);
        tr_html.append(td_zone_html);
        tr_html.append(td_environment_html);
        tr_html.append(td_machine_html);
        // tr_html.append(td_actions_html)
        $("#instances-list").append(tr_html);
        // Runs in case the page the loaded while an instances is pending.
        handleCheckState(instance.name);
        stateCheckIntervals[instance.name] = setInterval(handleCheckState, 5000, instance.name);
      }
    }

    function buildIconLoader() {
      return `<div class="preloader-wrapper small active" style="height:20px;width:20px">
        <div class="spinner-layer spinner-blue-only">
          <div class="circle-clipper left">
            <div class="circle"></div>
          </div><div class="gap-patch">
            <div class="circle"></div>
          </div><div class="circle-clipper right">
            <div class="circle"></div>
          </div>
        </div>
      </div>`
    }

    function buildDOMFromState(instance, state){
      var instanceFullNameId = instance.replaceAll('/', '_');
      attributes = {
        id: "state_" + instanceFullNameId,
        state: state,
      }
      content = "";
      if (state == 'ACTIVE') {
        attributes['class'] = 'material-icons green-text text-darken-2';
        content = stateDOMs[state]
      } else if (state == 'STOPPED') {
        attributes['class'] = 'material-icons';
        content = stateDOMs[state];
      } else if (['STOPPING', 'STARTING', 'PROVISIONING',
                  'UPGRADING', 'INITIALIZING', 'REGISTERING'].includes(state)) {
        content = buildIconLoader();
      } else {
        attributes['class'] = 'material-icons';
        content = stateDOMs[state];
      }
      snippet = "";
      snippet = $('<span>', attributes);
      snippet.html(content);
      return snippet;
    }

    function updateDOMState(instance, state) {
      var instanceFullNameId = instance.replaceAll('/', '_');
      var target = $("#state_" + instanceFullNameId);
      var currentContent = target.html();
      if (currentContent.includes(stateDOMs[state])){
        console.log('No need to update');
        return
      }
      newTarget = buildDOMFromState(instance, state);
      target.replaceWith(newTarget);
    }

    function updateDOMProject(pid) {
      $('#nav-span-pid').html("&nbsp;" + pid + "&nbsp;");
    }
  </script>
</head>
<body class="">
  <!-- Modal -->
  <div id="modal-projects" class="modal modal-fixed-footer">
    <div id="modal-project-list-loader" class="center-align">
      <div class="preloader-wrapper small active">
        <div class="spinner-layer spinner-blue-only">
          <div class="circle-clipper left">
            <div class="circle"></div>
          </div><div class="gap-patch">
            <div class="circle"></div>
          </div><div class="circle-clipper right">
            <div class="circle"></div>
          </div>
        </div>
      </div>
    </div>
    <div id="modal-project-list" class="modal-content">
      <div class="row"><h6>Select a project</h6></div>
      <div class="row">
        <table>
          <thead><tr><th>Name</th><th>Id</th></tr></thead>
          <tbody id="projects-list"></tbody>
        </table>
      </div>
    </div>
    <div class="modal-footer">
      <a href="#!" class="modal-close waves-effect waves-green btn-flat">Cancel</a>
    </div>
  </div>
  <!-- Dropdowns rightside-->
  <ul id="nav-dropdown-profile" class="dropdown-content">
    <li><span id="nav-name"></span></li>
    <li><span id="nav-email"></span></li>
    <li class="divider"></li>
    <li><a href="#" id="revoke-access-button"><i class="material-icons">remove_circle_outline</i>&nbsp;Revoke access</a></li>
    <li><a href="#" id="sign-out-button"><i class="material-icons">exit_to_app</i>&nbsp;Signout</a></li>
  </ul>
  <ul id="nav-dropdown-extra" class="dropdown-content">
    <li><a>Licenses</a></li>
    <li><a>Privacy</a></li>
  </ul>
  <nav class="navbar-fixed">
    <div class="nav-wrapper">
      <!-- Left side -->
      <ul class="left hide-on-med-and-down">
        <!-- Logo -->
        <li style="width: 80px">
          <svg style="fill: #fff;" width="100%" height="100%" viewBox="0 0 72 24" fit="" preserveAspectRatio="xMidYMid meet" focusable="false">
            <path xmlns="http://www.w3.org/2000/svg" d="M16 13l4.578-.11c-.185 1.204-.556 2.038-1.112 2.594-.74.74-1.853 1.483-3.8 1.483-3.057 0-5.467-2.502-5.467-5.56 0-3.06 2.41-5.56 5.466-5.56 1.668 0 2.873.648 3.707 1.482l1.482-1.3C19.56 4.827 17.89 3.9 15.575 3.9c-4.17 0-7.693 3.43-7.693 7.6s3.522 7.598 7.692 7.598c2.224 0 3.985-.74 5.282-2.13 1.39-1.39 1.76-3.338 1.76-4.913 0-.463-.016-.556-.016-1.055H16v2zm12.92-3.818c-2.69 0-4.913 2.04-4.913 4.912 0 2.873 2.224 4.91 4.912 4.91 2.685 0 4.91-2.037 4.91-4.91.092-2.873-2.13-4.912-4.91-4.912zm0 7.877c-1.484 0-2.78-1.206-2.78-2.967 0-1.76 1.296-2.966 2.78-2.966 1.482 0 2.78 1.205 2.78 2.966 0 1.76-1.298 2.965-2.78 2.965zm21.498-7.97c-2.41 0-4.633 2.13-4.633 4.91 0 2.78 2.13 4.912 4.633 4.912 1.205 0 2.132-.556 2.595-1.112h.093v.65c0 1.853-1.02 2.872-2.595 2.872-1.295 0-2.13-.927-2.5-1.76l-1.853.74c.556 1.298 1.946 2.874 4.355 2.874 2.503 0 4.49-1.357 4.49-5.097V9.366h-1.894v.834c-.556-.555-1.483-1.11-2.688-1.11zm.278 7.97c-1.482 0-2.594-1.3-2.594-2.967 0-1.76 1.112-2.966 2.594-2.966 1.483 0 2.595 1.298 2.595 2.966 0 1.668-1.11 2.965-2.593 2.965zm-10.75-7.88c-2.687 0-4.91 2.04-4.91 4.912 0 2.873 2.223 4.91 4.91 4.91 2.688 0 4.912-2.037 4.912-4.91s-2.224-4.912-4.91-4.912zm0 7.877c-1.482 0-2.78-1.205-2.78-2.966 0-1.76 1.298-2.965 2.78-2.965 1.483 0 2.78 1.205 2.78 2.966 0 1.76-1.297 2.966-2.78 2.966zM57 4.084h2v14.828h-2V4.085zm8.616 12.974c-1.112 0-1.853-.464-2.41-1.483l6.58-2.688-.277-.65c-.373-1.112-1.67-3.15-4.173-3.15s-4.633 1.946-4.633 4.91c0 2.78 2.04 4.913 4.91 4.913 2.226 0 3.523-1.39 4.08-2.132l-1.67-1.11c-.555.833-1.39 1.39-2.41 1.39zm-.185-6.117c.836 0 1.578.464 1.856 1.113l-4.45 1.853c0-2.038 1.484-2.965 2.596-2.965z" fill-rule="evenodd"></path>
          </svg>
        </li>
        <li style="width: 130px">
          <svg style="fill: #fff;" width="100%" height="100%" viewBox="0 0 130 24" fit="" preserveAspectRatio="xMidYMid meet" focusable="false">
            <path xmlns="http://www.w3.org/2000/svg" d="M9.176 19.283c2.316 0 4.263-1.02 5.56-2.502L13.53 15.58c-1.017 1.204-2.5 2.038-4.26 2.038-2.966 0-5.376-2.13-5.376-5.56 0-3.43 2.503-5.56 5.375-5.56 1.575 0 2.872.556 3.89 1.76l1.206-1.204c-1.206-1.482-3.06-2.317-5.098-2.317-4.077 0-7.228 3.15-7.228 7.32s3.058 7.23 7.136 7.23zm8.685-.278V5.012H16.1v13.993h1.76zm22.08 0V9.46h-1.92v5.286c0 1.483-1.01 2.954-2.52 2.954-1.345 0-2.5-.427-2.5-2.68V9.46h-2v5.84c0 2.315 1.733 3.988 4.027 3.988 1.235 0 2.797-.746 3.326-1.488h.088v1.113h1.5v.092zm5.85.278c1.484 0 2.69-.74 3.245-1.668h.092v1.298h1.76v-13.9h-1.76V9.46l.093 1.298h-.094c-.556-.834-1.76-1.668-3.243-1.668-2.41 0-4.54 2.13-4.54 5.097 0 2.965 2.038 5.096 4.447 5.096zm.28-1.668c-1.576 0-3.06-1.297-3.06-3.428 0-2.132 1.484-3.43 3.06-3.43 1.575 0 3.057 1.298 3.057 3.43 0 2.13-1.482 3.428-3.058 3.428zM59.87 13h2.966c2.367.05 4.356-1.668 4.356-4.02 0-2.352-2.04-3.968-4.356-3.968H58.11v13.993h1.76V13zm.1-1.83v-4.3h2.91c1.55 0 2.46 1.158 2.46 2.15s-.91 2.15-2.46 2.15h-2.91zm10.89 7.835V5.012H69v13.993h1.86zm8.204-1.39h.092v1.298h1.76v-5.746c0-2.687-1.945-4.077-4.262-4.077-2.41 0-3.52 1.482-3.892 2.316l1.668.742c.37-.927 1.298-1.39 2.317-1.39 1.39 0 2.502.834 2.502 2.316v.278c-.373-.185-1.3-.556-2.597-.556-2.224 0-3.892 1.14-3.892 3.273-.184 1.944 1.206 2.98 3.15 2.98 1.67 0 2.597-.602 3.153-1.436zm-4.624-1.598c0-.834.393-1.67 2.247-1.67 1.482 0 2.372.58 2.372.58 0 1.484-1.577 2.537-2.967 2.537-.927 0-1.654-.428-1.654-1.447zm14.072 2.803l-.65-1.575c-.277.092-.462.185-.833.185-.836 0-1.3-.463-1.13-1.575V11H88V9.46h-2.1l.13-2.436H84l-.03 2.436H82V11h2v5.133c0 2.008.99 2.965 3.03 2.965 0 0 1.018-.093 1.482-.278zM91 8.102V9.46h-1.892v1.56H91.1v7.985h1.86V11.02H96V9.46h-3.04V8.256c0-1.112.74-1.67 1.575-1.67.37 0 .556 0 .834.187l.647-1.576c-.37-.185-.834-.278-1.39-.278-2.04 0-3.53 1.235-3.628 3.18zM102 9c-2.925 0-5 2.182-5 5s2.075 5 5 5 5-2.182 5-5-2.075-5-5-5zM25 9c-2.925 0-5 2.182-5 5s2.075 5 5 5 5-2.182 5-5-2.075-5-5-5zm77 8.4c-1.5 0-3-1.287-3-3.4 0-2.114 1.412-3.4 3-3.4 1.5 0 3 1.286 3 3.4 0 2.113-1.5 3.4-3 3.4zm-77 0c-1.5 0-3-1.287-3-3.4 0-2.114 1.412-3.4 3-3.4 1.5 0 3 1.286 3 3.4 0 2.113-1.5 3.4-3 3.4zm84.946 1.605v-5.19c0-1.76 1.205-2.78 2.502-2.78.37 0 .742 0 .927.093l.65-1.668c-.372-.185-.743-.278-1.39-.278-1.02 0-2.41.742-2.782 1.76h-.092V9.46H108v9.545h1.946zm7.014 0v-5.282c-.2-1.483.82-2.965 2.21-2.965 1.39 0 2.132.926 1.83 2.965l.06 5.282H123v-5.282c.062-1.483.804-2.965 2.194-2.965s1.826.68 1.826 2.718v5.53l1.982-.006v-5.85c0-2.317-.982-3.968-3.3-3.968-1.482 0-2.454.742-3.103 1.854-.465-1.112-1.485-1.854-3.06-1.854-1.11 0-2.41.742-2.966 1.668V9.46H115v9.545h1.96z" fill-rule="evenodd"></path>
          </svg>
        </li>
        <!-- Select project -->
        <li id="nav-projects" style="display:none;padding:0 20;line-height:48px;color:#fff;">
          <a href="#" id="nav-projects-select" class="valign-wrapper">
            <span>
              <svg style="fill: #fff;" width="20px" height="20px" viewBox="0 0 18 18" fit="" preserveAspectRatio="xMidYMid meet" focusable="false"><path d="M10.557 11.99l-1.71-2.966 1.71-3.015h3.42l1.71 3.01-1.71 2.964h-3.42zM4.023 16l-1.71-2.966 1.71-3.015h3.42l1.71 3.01L7.443 16h-3.42zm0-8.016l-1.71-2.966 1.71-3.015h3.42l1.71 3.015-1.71 2.966h-3.42z" fill-rule="evenodd"></path></svg>
            </span>
            <span id="nav-span-pid">&nbsp;Select a project&nbsp;</span>
            <i class="material-icons">arrow_drop_down</i>
          </a>
        </li>
      </ul>
      <!-- Right side -->
      <ul id="nav-profile" class="right hide-on-med-and-down" style="display:none">
        <li>
          <a class="dropdown-trigger" href="#!" data-target="nav-dropdown-extra">
            <i class="material-icons">more_vert</i>
          </a>
        </li>
        <li>
          <a class="dropdown-trigger" href="#!" data-target="nav-dropdown-profile">
            <img alt="" class="circle" id="nav-avatar" style="height: 42px; padding:4 4 0 0;">
          </a>
        </li>
      </ul>
    </div>
  </nav>
  <!-- Body -->
  <div id="body-no-authenticated" style="display: none;">
    <div class="row center-align">
      <a id="sign-in-button" class="waves-effect waves-light blue darken-3 btn">Signin</a>
    </div>
  </div>
  <div id="general-loader" class="center-align">
    <div class="preloader-wrapper small active">
      <div class="spinner-layer spinner-blue-only">
        <div class="circle-clipper left">
          <div class="circle"></div>
        </div><div class="gap-patch">
          <div class="circle"></div>
        </div><div class="circle-clipper right">
          <div class="circle"></div>
        </div>
      </div>
    </div>
  </div>
  <div id="body-no-project" class="center-align" style="display:none;">
    <div class="row">
      <i class="material-icons" style="font-size:100px">blur_on</i>
    </div>
    <div class="row">
      Please select a project.
    </div>
  </div>
  <div id="body-content" style="display:none;">
    <!-- Action bar -->
    <div class="row valign-wrapper">
      <div class="col s1">
        <h6>Notebooks</h6>
      </div>
      <div class="col s8">&nbsp;</div>
      <div class="col s1">
        <a class="upper_case valign-wrapper" id="list-instances-button">
          <i class="material-icons">refresh</i>
          <span>&nbsp;Refresh</span>
        </a>
      </div>
      <div class="col s1">
        <a class="upper_case valign-wrapper" id="action-instances-start">
          <i class="material-icons">play_arrow</i>
          <span>&nbsp;Start</span>
        </a>
      </div>
      <div class="col s1">
        <a class="upper_case valign-wrapper" id="action-instances-stop">
          <i class="material-icons">stop</i>
          <span>&nbsp;Stop</span>
        </a>
      </div>
    </div>
    <div class="divider"></div>
    <!-- -->
    <div class="row valign-wrapper m-b-s">
      <div class="col s12"><p>Start and stop your existing notebook instances.</p></div>
    </div>
    <!-- Results -->
    <div id="body-results-loader" class="center-align" style="display:none;">
      <div class="preloader-wrapper small active">
        <div class="spinner-layer spinner-blue-only">
          <div class="circle-clipper left">
            <div class="circle"></div>
          </div><div class="gap-patch">
            <div class="circle"></div>
          </div><div class="circle-clipper right">
            <div class="circle"></div>
          </div>
        </div>
      </div>
    </div>
    <div id="body-results" style="display:none;">
      <table>
        <thead>
          <tr>
              <th></th>
              <th></th>
              <th>Instance name</th>
              <th></th>
              <th>Zone</th>
              <th>Environment</th>
              <th>Machine Type</th>
          </tr>
        </thead>
        <tbody id="instances-list"></tbody>
      </table>
    </div>
  </div>
  <script src="${relative_path}/javascript/config.js"></script>
  <script src="${relative_path}/third_party/jquery/jquery.min.js"></script>
  <script src="${relative_path}/third_party/materialize/materialize.min.js"></script>
  <script async defer src="${relative_path}/third_party/api.js"
          onload="this.onload=function(){};handleClientLoad()"
          onreadystatechange="if (this.readyState === 'complete') this.onload()">
  </script>
</body>
</html>