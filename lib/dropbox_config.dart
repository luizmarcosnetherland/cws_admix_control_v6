const dropboxClientId = '9mxsdolwe6fhmvc';
const dropboxRedirectUri = 'com.netherland.cwsadmix://oauth2redirect';

const dropboxScopes = <String>[
  'account_info.read',
  'files.metadata.read',
  'files.content.read',
  'files.content.write',
  'sharing.read',
];

const dropboxAuthEndpoint = 'https://www.dropbox.com/oauth2/authorize';
const dropboxTokenEndpoint = 'https://api.dropboxapi.com/oauth2/token';
