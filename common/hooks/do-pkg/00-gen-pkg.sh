# This hook generates a XBPS binary package from an installed package in destdir.

genpkg() {
	local pkgdir="$1" arch="$2" desc="$3" pkgver="$4" binpkg="$5" _deps= f=

	if [ ! -d "${PKGDESTDIR}" ]; then
		msg_warn "$pkgver: cannot find pkg destdir... skipping!\n"
		return 0
	fi

	[ ! -d $pkgdir ] && mkdir -p $pkgdir

	while [ -f $pkgdir/${binpkg}.lock ]; do
		msg_warn "${pkgver}: binpkg is being created, waiting for 1s...\n"
		sleep 1
	done

	# Don't overwrite existing binpkgs by default, skip them.
	if [ -f $pkgdir/$binpkg -a -z "$XBPS_BUILD_FORCEMODE" ]; then
		msg_normal "${pkgver}: skipping existing $binpkg pkg...\n"
		return 0
	fi

	touch -f $pkgdir/${binpkg}.lock

	if [ ! -d $pkgdir ]; then
		mkdir -p $pkgdir
	fi
	cd $pkgdir

	if [ -n "$preserve" ]; then
		_preserve="-p"
	fi
	if [ -s ${PKGDESTDIR}/rdeps ]; then
		_deps="$(cat ${PKGDESTDIR}/rdeps)"
	fi
	if [ -s ${PKGDESTDIR}/shlib-provides ]; then
		_shprovides="$(cat ${PKGDESTDIR}/shlib-provides)"
	fi
	if [ -s ${PKGDESTDIR}/shlib-requires ]; then
		_shrequires="$(cat ${PKGDESTDIR}/shlib-requires)"
	fi
	if [ -s ${wrksrc}/.xbps_${sourcepkg}_git_revs ]; then
		_gitrevs="$(cat ${wrksrc}/.xbps_${sourcepkg}_git_revs)"
	fi

	if [ -n "$provides" ]; then
		local _provides=
		for f in ${provides}; do
			_provides="${_provides} ${f}"
		done
	fi
	if [ -n "$conflicts" ]; then
		local _conflicts=
		for f in ${conflicts}; do
			_conflicts="${_conflicts} ${f}"
		done
	fi
	if [ -n "$replaces" ]; then
		local _replaces=
		for f in ${replaces}; do
			_replaces="${_replaces} ${f}"
		done
	fi
	if [ -n "$mutable_files" ]; then
		local _mutable_files=
		for f in ${mutable_files}; do
			_mutable_files="${_mutable_files} ${f}"
		done
	fi
	if [ -n "$conf_files" ]; then
		local _conf_files=
		for f in ${conf_files}; do
			_conf_files="${_conf_files} ${f}"
		done
	fi

	msg_normal "Creating $binpkg for repository $pkgdir ...\n"

	#
	# Create the XBPS binary package.
	#
	xbps-create \
		--architecture ${arch} \
		--provides "${_provides}" \
		--conflicts "${_conflicts}" \
		--replaces "${_replaces}" \
		--mutable-files "${_mutable_files}" \
		--dependencies "${_deps}" \
		--config-files "${_conf_files}" \
		--homepage "${homepage}" \
		--license "${license}" \
		--maintainer "${maintainer}" \
		--desc "${desc}" \
		--built-with "xbps-src-${XBPS_SRC_VERSION}" \
		--build-options "${PKG_BUILD_OPTIONS}" \
		--pkgver "${pkgver}" --quiet \
		--source-revisions "${_gitrevs}" \
		--shlib-provides "${_shprovides}" \
		--shlib-requires "${_shrequires}" \
		${_preserve} ${_sourcerevs} ${PKGDESTDIR}
	rval=$?

	rm -f $pkgdir/${binpkg}.lock

	if [ $rval -ne 0 ]; then
		rm -f $pkgdir/$binpkg
		msg_error "Failed to created binary package: $binpkg!\n"
	fi
}

hook() {
	local arch= binpkg= repo= _pkgver= _desc=

	if [ -n "$noarch" ]; then
		arch=noarch
	elif [ -n "$XBPS_TARGET_MACHINE" ]; then
		arch=$XBPS_TARGET_MACHINE
	else
		arch=$XBPS_MACHINE
	fi
	if [ -z "$noarch" -a -z "$XBPS_CROSS_BUILD" -a -n "$XBPS_ARCH" -a "$XBPS_ARCH" != "$XBPS_TARGET_MACHINE" ]; then
		arch=${XBPS_ARCH}
	fi

	binpkg=${pkgver}.${arch}.xbps

	if [ -n "$nonfree" ]; then
		repo=$XBPS_REPOSITORY/nonfree
	else
		repo=$XBPS_REPOSITORY
	fi

	genpkg ${repo} ${arch} "${short_desc}" ${pkgver} ${binpkg}

	# Generate -dbg pkg.
	if [ -d "${XBPS_DESTDIR}/${XBPS_CROSS_TRIPLET}/${pkgname}-dbg-${version}" ]; then
		repo=$XBPS_REPOSITORY/debug
		_pkgver=${pkgname}-dbg-${version}_${revision}
		_desc="${short_desc} (debug files)"
		binpkg=${_pkgver}.${arch}.xbps
		PKGDESTDIR="${XBPS_DESTDIR}/${XBPS_CROSS_TRIPLET}/${pkgname}-dbg-${version}"
		genpkg ${repo} ${arch} "${_desc}" ${_pkgver} ${binpkg}
	fi
	# Generate 32bit pkg.
	if [ "$XBPS_TARGET_MACHINE" != "i686" ]; then
		return
	fi
	if [ -d "${XBPS_DESTDIR}/${pkgname}-32bit-${version}" ]; then
		unset conf_files provides replaces preserve
		if [ -n "$nonfree" ]; then
			repo=$XBPS_REPOSITORY/multilib/nonfree
		else
			repo=$XBPS_REPOSITORY/multilib
		fi
		_pkgver=${pkgname}-32bit-${version}_${revision}
		_desc="${short_desc} (32bit)"
		binpkg=${_pkgver}.x86_64.xbps
		PKGDESTDIR="${XBPS_DESTDIR}/${pkgname}-32bit-${version}"
		genpkg ${repo} x86_64 "${_desc}" ${_pkgver} ${binpkg}
	fi
}
