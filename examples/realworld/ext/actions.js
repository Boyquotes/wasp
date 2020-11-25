import { createNewUser } from '@wasp/core/auth.js'
import HttpError from '@wasp/core/HttpError.js'
import slug from 'slug'

export const signup = async ({ username, email, password }, context) => {
  try {
    console.log('juhu')
    await createNewUser({ username, email, password })
  } catch (err) {
    // TODO: I wish I didn't have to do this, I would love this to be in some
    //   degree done automatically.
    if (err.code == 'P2002') {
      throw new HttpError(400, err.meta.target + " must be unique.")
    }
    throw err
  }
}

export const updateUser = async ({ email, username, bio, profilePictureUrl, newPassword }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  await context.entities.User.update({
    where: { id: context.user.id },
    data: {
      email,
      username,
      bio,
      profilePictureUrl,
      // TODO: This is a problem because I save non-hashed password!!!!
      //   We somehow need to make it really hard (or impossible) for user to do this by mistake,
      //   because if even I did it by mistake, it is likely to happen again.
      //   I was used to mongoose doing hashing on save and was not aware it will just save it plain as day.
      //   Actually, is there even a mechanism I can use to change this password?
      //   I don't think so!
      password: newPassword || undefined
    }
  })
}

export const createArticle = async ({ title, description, markdownContent, tags }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  return await context.entities.Article.create({
    data: {
      title,
      slug: slug(title) + '-' + (Math.random() * Math.pow(36, 6) | 0).toString(36),
      description,
      markdownContent,
      user: { connect: { id: context.user.id } },
      tags: { connectOrCreate: tags.map(tag => ({ where: tag, create: tag })) }
    }
  })
}

export const updateArticle = async ({ id, title, description, markdownContent, tags }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  if (!await context.entities.Article.findFirst({
    where: { id, user: { id: context.user.id }} // TODO: This line is not fun to write.
  })) {
    throw new HttpError(404)
  }

  await context.entities.Article.update({
    where: { id },
    data: {
      title,
      description,
      markdownContent,
      tags: { connectOrCreate: tags.map(tag => ({ where: tag, create: tag })) }
    }
  })
}

export const deleteArticle = async ({ id }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  await context.entities.Article.deleteMany({
    where: { id, user: { id: context.user.id }} // TODO: This line is not fun to write.
  })
}

export const createComment = async ({ articleId, content }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  return await context.entities.Comment.create({
    data: {
      content,
      user: { connect: { id: context.user.id } },
      article: { connect: { id: articleId } }
    }
  })
}

export const deleteComment = async ({ id }, context) => {
  if (!context.user) { throw new HttpError(403) }

  // TODO: Nicer error handling! Right now everything is returned as 500 while it could be instead
  //   useful error message about username being taken / not unique, and other validation errors.
  await context.entities.Comment.deleteMany({
    where: { id, user: { id: context.user.id }} // TODO: This line is not fun to write.
  })
}
