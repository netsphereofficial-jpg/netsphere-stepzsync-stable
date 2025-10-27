import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isBack;
  final VoidCallback? onBackClick;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? titleColor;
  final IconData? iconData;
  final bool showMenuIcon;
  final VoidCallback? onMenuClick;
  final Widget? leading;
  final bool circularBackButton;
  final Color? backButtonCircleColor;
  final Color? backButtonIconColor;
  final TextStyle? titleStyle;
  final bool showGradient;

  const CustomAppBar({
    super.key,
    required this.title,
    this.isBack = false,
    this.onBackClick,
    this.actions,
    this.backgroundColor,
    this.titleColor,
    this.iconData,
    this.showMenuIcon = false,
    this.onMenuClick,
    this.leading,
    this.circularBackButton = false,
    this.backButtonCircleColor,
    this.backButtonIconColor,
    this.titleStyle,
    this.showGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: titleStyle ?? GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: titleColor ?? Colors.white,
        ),
      ),
      backgroundColor: backgroundColor ?? AppColors.appColor,
      foregroundColor: titleColor ?? Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: leading ?? (isBack
          ? (Navigator.canPop(context)
              ? (circularBackButton
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: backButtonCircleColor ?? AppColors.neonYellow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: IconButton(
                            icon: Icon(
                              iconData ?? Icons.arrow_back_ios_new_rounded,
                              color: backButtonIconColor ?? Colors.black,
                              size: 18,
                            ),
                            onPressed: onBackClick ?? () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        iconData ?? Icons.arrow_back_ios_rounded,
                        color: titleColor ?? Colors.white,
                      ),
                      onPressed: onBackClick ?? () => Navigator.of(context).pop(),
                    ))
              : null)
          : (showMenuIcon
              ? Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: titleColor ?? Colors.white,
                    ),
                    onPressed: onMenuClick ?? () {
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                )
              : null)),
      actions: actions,
      flexibleSpace: showGradient
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.appColor, AppColors.appColor.withValues(alpha: 0.8)],
                ),
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}