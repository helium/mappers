const DOMAIN = '/api/v1/'

export const get = (url) => fetch(DOMAIN + url)