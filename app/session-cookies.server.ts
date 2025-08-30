import { createCookieSessionStorage } from "react-router"


const AUTH_SECRET = process.env.AUTH_SECRET;
if (!AUTH_SECRET || AUTH_SECRET.length < 32) {
  throw new Error("AUTH_SECRET must be set to a strong random value");
}
type SessionData = {
    userId: string
}

type SessionFlashData = {
    error: string
}

const { getSession, commitSession, destroySession } =
    createCookieSessionStorage<SessionData, SessionFlashData>({
        // a Cookie from `createCookie` or the CookieOptions to create one
        cookie: {
            name: "mcp_secret",

            isSigned: true,

            httpOnly: true,
            // Set to expire in year 9999 (effectively never)
            // maxAge: 60 * 60 * 24 * 180,
            path: "/",
            sameSite: "lax",
            secrets: [AUTH_SECRET],
            secure: true,
        },
    })

export { getSession, commitSession, destroySession }
