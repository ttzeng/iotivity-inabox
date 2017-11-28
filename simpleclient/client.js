var ocf = require('iotivity-node'),
    client = ocf.client;

var switchesFound;

function serverError(error) {
    log('Server return error:', error.message);
}

function observeResource(resource) {
    if (('properties' in resource) && ('value' in resource.properties)) {
        var id = resource.deviceId + ':' + resource.resourcePath;
        document.getElementById(id).checked = resource.properties.value;
    }
}

function deleteResource() {
    var id = this.deviceId + ':' + this.resourcePath;
    log('deleteResource(' + this.resourcePath + ')');

    var resource = switchesFound[id];
    if (resource) {
        resource.removeListener('update', observeResource);
        resource.removeListener('delete', deleteResource);
        delete switchesFound[id];

        var child = document.getElementById(id);
        var parent = child.parentElement;
        while (parent.id != 'resources')
            child = parent, parent = parent.parentElement;
        if (parent.childElementCount > 1)
            parent.removeChild(child);
        else {
            // remove from layout instead of from DOM
            parent.style.display = 'none';
        }
    }
}

function resourceFound(resource) {
    log('Resource found: ' + resource.deviceId);
    var id = resource.deviceId + ':' + resource.resourcePath;
    if (!switchesFound[id]) {
        switchesFound[id] = resource;
        resource.addListener('update', observeResource);
        resource.addListener('delete', deleteResource);
        resource.addListener('error' , serverError);
        addResourceHolderToUI(resource);
    }
}

function discoverBinarySwitch() {
    log('Discovering...');
    purgeAllResourceHoldersFromUI();
    switchesFound = {};
    client.on('error', serverError)
          .findResources({ 'resourceType': ['oic.r.switch.binary'] }, resourceFound).then(
        function() {
            log('findResources() successful');
        },
        function(error) {
            log('findResources() failed with ' + error);
        });
}

function log(string) {
    document.getElementById('statusBar').innerHTML = string;
}

function purgeAllResourceHoldersFromUI() {
    var cards = document.getElementById('resources');
    while (cards.childElementCount > 1)
        cards.removeChild(cards.lastElementChild);
    cards.style.display = 'none';
}

function addResourceHolderToUI(resource) {
    var cards = document.getElementById('resources'),
        node = cards.firstElementChild;
    if (cards.style.display === 'none') {
        cards.style.display = 'block';
    } else {
        node = node.cloneNode(true);
        cards.appendChild(node);
    }
    node.getElementsByClassName('resourceUUID')[0].innerHTML = resource.deviceId;
    node.getElementsByClassName('resourcePath')[0].innerHTML = resource.resourcePath;
    var checkbox = node.getElementsByClassName('checkbox')[0];
    checkbox.id = resource.deviceId + ':' + resource.resourcePath;
    checkbox.onclick = function() {
        var resource = switchesFound[this.id];
        resource.properties.value = this.checked;
        client.update(resource);
    }
}