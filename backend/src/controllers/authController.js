const { OAuth2Client } = require('google-auth-library');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const prisma = require('../config/database');
const logger = require('../config/logger');

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

class AuthController {
  async googleLogin(req, res) {
    try {
      const { token } = req.body;

      // Verify Google token
      const ticket = await client.verifyIdToken({
        idToken: token,
        audience: process.env.GOOGLE_CLIENT_ID
      });

      const payload = ticket.getPayload();
      const { sub: googleId, email, name, picture } = payload;

      if (!email) {
        return res.status(400).json({ 
          error: 'Invalid token',
          message: 'Email not found in Google token' 
        });
      }

      // Find or create user
      let user = await prisma.user.findUnique({
        where: { email }
      });

      if (!user) {
        // Create new user
        user = await prisma.user.create({
          data: {
            email,
            googleId,
            name: name || email.split('@')[0],
            profilePicture: picture || null,
            isActive: true,
            lastLoginAt: new Date()
          }
        });

        logger.info(`New user created: ${email}`);
      } else {
        // Update existing user
        user = await prisma.user.update({
          where: { id: user.id },
          data: {
            googleId: googleId,
            name: name || user.name,
            profilePicture: picture || user.profilePicture,
            lastLoginAt: new Date()
          }
        });

        logger.info(`User logged in: ${email}`);
      }

      // Check if user is active
      if (!user.isActive) {
        return res.status(403).json({ 
          error: 'Account disabled',
          message: 'Your account has been disabled. Please contact an administrator.' 
        });
      }

      // Generate JWT tokens
      const accessToken = jwt.sign(
        { 
          userId: user.id, 
          email: user.email,
          isAdmin: user.isAdmin 
        },
        process.env.JWT_SECRET,
        { expiresIn: '1h' }
      );

      const refreshToken = jwt.sign(
        { userId: user.id },
        process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET,
        { expiresIn: '7d' }
      );

      // Save refresh token
      await prisma.user.update({
        where: { id: user.id },
        data: { refreshToken }
      });

      res.json({
        message: 'Login successful',
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          profilePicture: user.profilePicture,
          isAdmin: user.isAdmin,
          preferences: user.preferences
        },
        tokens: {
          accessToken,
          refreshToken
        }
      });
    } catch (error) {
      logger.error('Google login error:', error);
      
      if (error.message.includes('Token used too late')) {
        return res.status(400).json({ 
          error: 'Token expired',
          message: 'Google token has expired. Please try logging in again.' 
        });
      }
      
      res.status(500).json({ 
        error: 'Authentication failed',
        message: 'An error occurred during authentication' 
      });
    }
  }

  async refreshToken(req, res) {
    try {
      const { refreshToken } = req.body;

      if (!refreshToken) {
        return res.status(401).json({ 
          error: 'Refresh token required',
          message: 'No refresh token provided' 
        });
      }

      // Verify refresh token
      const decoded = jwt.verify(
        refreshToken, 
        process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET
      );

      // Find user and verify refresh token
      const user = await prisma.user.findFirst({
        where: {
          id: decoded.userId,
          refreshToken: refreshToken,
          isActive: true
        }
      });

      if (!user) {
        return res.status(401).json({ 
          error: 'Invalid refresh token',
          message: 'Refresh token is invalid or expired' 
        });
      }

      // Generate new access token
      const accessToken = jwt.sign(
        { 
          userId: user.id, 
          email: user.email,
          isAdmin: user.isAdmin 
        },
        process.env.JWT_SECRET,
        { expiresIn: '1h' }
      );

      // Optionally generate new refresh token
      const newRefreshToken = jwt.sign(
        { userId: user.id },
        process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET,
        { expiresIn: '7d' }
      );

      // Update refresh token in database
      await prisma.user.update({
        where: { id: user.id },
        data: { refreshToken: newRefreshToken }
      });

      res.json({
        message: 'Token refreshed successfully',
        tokens: {
          accessToken,
          refreshToken: newRefreshToken
        }
      });
    } catch (error) {
      logger.error('Refresh token error:', error);
      
      if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
        return res.status(401).json({ 
          error: 'Invalid refresh token',
          message: 'Refresh token is invalid or expired' 
        });
      }
      
      res.status(500).json({ 
        error: 'Token refresh failed',
        message: 'An error occurred while refreshing the token' 
      });
    }
  }

  async logout(req, res) {
    try {
      // Clear refresh token from database
      await prisma.user.update({
        where: { id: req.user.id },
        data: { refreshToken: null }
      });

      res.json({ message: 'Logout successful' });
    } catch (error) {
      logger.error('Logout error:', error);
      res.status(500).json({ 
        error: 'Logout failed',
        message: 'An error occurred during logout' 
      });
    }
  }

  async getProfile(req, res) {
    try {
      const user = await prisma.user.findUnique({
        where: { id: req.user.id },
        select: {
          id: true,
          email: true,
          name: true,
          profilePicture: true,
          isAdmin: true,
          preferences: true,
          createdAt: true,
          lastLoginAt: true
        }
      });

      if (!user) {
        return res.status(404).json({ error: 'User not found' });
      }

      res.json(user);
    } catch (error) {
      logger.error('Get profile error:', error);
      res.status(500).json({ error: 'Failed to get profile' });
    }
  }
}

module.exports = new AuthController();
