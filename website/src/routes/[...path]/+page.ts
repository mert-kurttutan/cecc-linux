import { prerenderPaths } from '../../content'

export const entries = () =>
  prerenderPaths
    .filter((path) => path !== '/')
    .map((path) => ({
      path: path.slice(1),
    }))
