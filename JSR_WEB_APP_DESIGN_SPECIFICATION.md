# JSR Web App Design Specification

## Overview
This document outlines the design system and UI patterns from the JSR Web App (EassyLife Task Management System) that should be implemented in the Flutter Task Tool application.

## Color Palette

### Primary Colors
- **Primary**: `#FFA301` (Orange/Yellow)
- **Primary Variants**:
  - `50`: `#FFF8E6`
  - `100`: `#FFECB3`
  - `200`: `#FFE080`
  - `300`: `#FFD54D`
  - `400`: `#FFCA1A`
  - `500`: `#FFA301` (Main)
  - `600`: `#E6920E`
  - `700`: `#CC8200`
  - `800`: `#B37200`
  - `900`: `#996200`

### Neutral Colors
- **Black**: `#000000`
- **White**: `#FFFFFF`
- **Gray Scale**:
  - `50`: `#F8F8F8`
  - `100`: `#F0F0F0`
  - `200`: `#E8E8E8`
  - `300`: `#D0D0D0`
  - `400`: `#A0A0A0`
  - `500`: `#808080`
  - `600`: `#606060`
  - `700`: `#404040`
  - `800`: `#202020`
  - `900`: `#101010`

## Typography

### Font Family
- **Primary**: Signika (Custom font family)
- **Fallback**: system-ui, sans-serif
- **Weights Available**: 300 (Light), 400 (Regular), 500 (Medium), 600 (SemiBold), 700 (Bold)

### Text Hierarchy
- **H1**: 2xl, font-bold, text-black
- **H2**: xl, font-bold, text-black  
- **H3**: lg, font-semibold, text-black
- **Body**: sm/base, font-medium, text-black
- **Caption**: xs, font-medium, text-gray-600
- **Label**: xs, font-medium, text-gray-500, uppercase, tracking-wider

## Layout Structure

### Navigation
- **Type**: Horizontal tab-based navigation with sticky header
- **Structure**: 
  - Top row: Logo + Title + User menu + Logout
  - Bottom row: Navigation tabs (role-based)
- **Mobile**: Collapsible hamburger menu
- **Background**: White with shadow and backdrop blur
- **Height**: 16 units (64px) for header + additional for tabs

### Content Layout
- **Container**: max-w-7xl mx-auto px-4 sm:px-6 lg:px-8
- **Background**: Gray-50 (#F8F8F8)
- **Spacing**: py-8 for main content area
- **Grid**: Responsive grid system (1/2/3/4 columns based on screen size)

## Component Styles

### Cards
- **Base**: `bg-white rounded-lg shadow-sm border border-gray-200 p-6`
- **Hover**: `hover:shadow-md transition-shadow duration-200`
- **Animation**: `animate-fade-in` for entrance

### Buttons
- **Primary**: `bg-primary hover:bg-primary-600 text-black font-medium py-2 px-4 rounded-lg`
- **Secondary**: `bg-white hover:bg-gray-50 text-black border border-gray-300`
- **Transitions**: `transition-all duration-200`
- **Focus**: `focus:ring-2 focus:ring-primary focus:ring-offset-2`

### Status Badges
- **Yet to Start**: `bg-gray-100 text-black border border-gray-300`
- **In Progress**: `bg-primary-100 text-black border border-primary-300`
- **Done**: `bg-primary text-black border border-primary-600`
- **Delayed**: `bg-red-100 text-red-800 border border-red-300`
- **Style**: `px-2 py-1 rounded-full text-xs font-medium`

### Priority Badges
- **U&I (Urgent & Important)**: `bg-primary text-black border border-primary-600`
- **NU&I (Not Urgent but Important)**: `bg-primary-200 text-black border border-primary-400`
- **U&NI (Urgent but Not Important)**: `bg-primary-100 text-black border border-primary-300`
- **NU&NI (Not Urgent & Not Important)**: `bg-gray-100 text-black border border-gray-300`

### Input Fields
- **Base**: `w-full px-3 py-2 border border-gray-300 rounded-lg bg-white text-black`
- **Focus**: `focus:ring-2 focus:ring-primary focus:border-transparent`
- **Placeholder**: `placeholder-gray-500`
- **With Icon**: `pl-10` with absolute positioned icon

### Stats Cards
- **Layout**: Flex with icon on right, content on left
- **Icon Container**: `p-3 rounded-lg` with color-specific background
- **Hover**: `hover:shadow-lg hover:scale-105 transform` if clickable
- **Active State**: `ring-2 ring-primary ring-opacity-50 bg-primary-50`

## Animations & Transitions

### Standard Animations
- **Fade In**: `opacity: 0 → 1, translateY: 10px → 0` over 0.3s ease-out
- **Scale In**: `opacity: 0 → 1, scale: 0.95 → 1` over 0.2s ease-out
- **Slide In**: `opacity: 0 → 1, translateX: -20px → 0` over 0.3s ease-out
- **Hover Lift**: `translateY: 0 → -2px` with shadow increase

### Loading States
- **Shimmer**: Linear gradient animation for skeleton loading
- **Spinner**: Rotating border animation with primary color
- **Pulse**: Opacity animation for loading placeholders

## Responsive Breakpoints
- **Mobile**: < 768px (md)
- **Tablet**: 768px - 1024px (md-lg)
- **Desktop**: > 1024px (lg+)

### Mobile Adaptations
- Navigation collapses to hamburger menu
- Grid layouts stack vertically
- Padding and spacing reduced
- Text sizes adjusted for readability

## Interactive States

### Hover Effects
- **Cards**: Shadow increase and subtle lift
- **Buttons**: Background color change and shadow
- **Navigation**: Background color and text color change
- **Stats Cards**: Scale and shadow effects

### Focus States
- **Inputs**: Ring outline with primary color
- **Buttons**: Ring outline with appropriate color
- **Navigation**: Visible focus indicators

### Active States
- **Navigation**: Primary background with enhanced styling
- **Stats Cards**: Ring outline and background tint
- **Buttons**: Pressed state with darker background

## Special Features

### Role-Based UI
- **Admin**: User management focus, system statistics
- **Employee**: Task-focused interface, personal actions
- **Top Management**: Reports and approvals focus

### Loading & Empty States
- **Skeleton Loading**: Consistent shimmer animations
- **Empty States**: Centered icon + message + action button
- **Error States**: Clear error messages with retry options

### Accessibility
- **Color Contrast**: WCAG AA compliant
- **Focus Management**: Visible focus indicators
- **Screen Reader**: Proper ARIA labels and semantic HTML
- **Keyboard Navigation**: Full keyboard accessibility

## Implementation Notes

### CSS Framework
- **Base**: Tailwind CSS with custom configuration
- **Custom Classes**: Defined in globals.css for reusable patterns
- **Animations**: Custom keyframes and utility classes

### Font Loading
- **Strategy**: Font-display: swap for performance
- **Fallbacks**: System fonts as backup
- **Preloading**: Critical font weights preloaded

### Performance Considerations
- **Animations**: Hardware-accelerated transforms
- **Images**: Optimized loading and sizing
- **Transitions**: Reasonable durations (200-300ms)
- **Hover Effects**: Minimal performance impact
