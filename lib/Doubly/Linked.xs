#define PERL_NO_GET_CONTEXT // we'll define thread context if necessary (faster)
#include "EXTERN.h"         // globals/constant import locations
#include "perl.h"           // Perl symbols, structures and constants definition
#include "XSUB.h"           // xsubpp functions and macros

int _defined (HV * hash, char * key, int len) {
	SV * val = *hv_fetch(hash, key, len, 0);
	return SvOK(val) ? 1 : 0;
}

int _is_undef (SV * self) {
	HV * hash = (HV*)SvRV(self);
	
	if (SvOK(*hv_fetch(hash, "data", 4, 0))) {
		return 0;
	}

	if (SvOK(*hv_fetch(hash, "prev", 4, 0))) {
		return 0;
	}

	if (SvOK(*hv_fetch(hash, "next", 4, 0))) {
		return 0;
	}
	
	return 1;
}

SV * _set_data(SV * self, SV * data) {
	HV * hash = (HV*)SvRV(self);
	*hv_store(hash, "data", 4, data, 0);
	return newSVsv(self);
}

SV * _new (SV * pkg, SV * data) {
	dTHX;
	HV * hash = newHV();
	if (SvTYPE(pkg) != SVt_PV) {
		char * name = HvNAME(SvSTASH(SvRV(pkg)));
		pkg = newSVpv(name, strlen(name));
	}
	SV * undef = &PL_sv_undef;
	*hv_store(hash, "data", 4, data, 0);
	*hv_store(hash, "next", 4, undef, 0);
	*hv_store(hash, "prev", 4, undef, 0);
	return sv_bless(newRV_noinc((SV*)hash), gv_stashsv(pkg, 0));
}

SV * _start ( SV * self ) {
	HV * hash = (HV*)SvRV(self);

	while (_defined(hash, "prev", 4)) {
		self = *hv_fetch(hash, "prev", 4, 0);
		hash = (HV*)SvRV(self);
	}

	return self;
}


SV * _is_start ( SV * self ) {
	HV * hash = (HV*)SvRV(self);

	if (_defined(hash, "prev", 4)) {
		return newSViv(0);
	}
	return newSViv(1);
}

SV * _end ( SV * self ) {
	HV * hash = (HV*)SvRV(self);

	while (_defined(hash, "next", 4)) {
		self = *hv_fetch(hash, "next", 4, 0);
		hash = (HV*)SvRV(self);
	}

	return self;
}

SV * _is_end ( SV * self ) {
	HV * hash = (HV*)SvRV(self);

	if (_defined(hash, "next", 4)) {
		return newSViv(0);
	}
	return newSViv(1);
}


SV * _find ( SV * self, SV * cb ) {
	dTHX;

	self = _start(self);
	HV * hash = (HV*)SvRV(self);
	SV * data = *hv_fetch(hash, "data", 4, 0);

	dSP;
	PUSHMARK(SP);
	XPUSHs(data);
	PUTBACK;	
	call_sv(cb, G_SCALAR);
	if (SvTRUEx(*PL_stack_sp)) {
		return newSVsv(self);
	}
	
	while (_defined(hash, "next", 4)) {
		self = *hv_fetch(hash, "next", 4, 0);
		hash = (HV*)SvRV(self);
		data = *hv_fetch(hash, "data", 4, 0);
		PUSHMARK(SP);
		XPUSHs(data);
		PUTBACK;
		call_sv(cb, G_SCALAR);
		if (SvTRUEx(*PL_stack_sp)) {
			return newSVsv(self);
		}
	}

	return &PL_sv_undef;
}

SV * _insert_before (SV * self, SV * data) {
	dTHX;	
	if (_is_undef(self)) {
		return _set_data(self, data);
	}

	HV * hash = (HV*)SvRV(self);
	
	SV * node = _new(self, data);
	HV * hash_node = (HV*)SvRV(node);

	*hv_store(hash_node, "next", 4, newSVsv(self), 0);
	
	SV * prev = newSVsv(*hv_fetch(hash, "prev", 4, 0));

	if (SvOK(prev) && SvROK(prev)) {
		*hv_store((HV*)SvRV(prev), "next", 4, newSVsv(node), 0);
	}

	*hv_store(hash_node, "prev", 4, prev, 0);

	*hv_store(hash, "prev", 4, newSVsv(node), 0);

	return node;
}

SV * _insert_after (SV * self, SV * data) {
	dTHX;
	if (_is_undef(self)) {
		return _set_data(self, data);
	}

	HV * hash = (HV*)SvRV(self);

	SV * node = _new(self, data);
	HV * hash_node = (HV*)SvRV(node);

	*hv_store(hash_node, "prev", 4, newSVsv(self), 0);
	
	SV * next = newSVsv(*hv_fetch(hash, "next", 4, 0));

	if (SvOK(next) && SvROK(next)) {
		*hv_store((HV*)SvRV(next), "prev", 4, newSVsv(node), 0);
	}

	*hv_store(hash_node, "next", 4, next, 0);

	*hv_store(hash, "next", 4, newSVsv(node), 0);

	return node;
}

SV * _insert (SV * self, SV * cb, SV * data) {
	dTHX;
	if (_is_undef(self)) {
		return _set_data(self, data);
	}

	self = _find(self, cb);

	if (!SvOK(self)) {
		croak("No match found for insert cb");
	}
	
	return _insert_before(self, data);
}

SV * _insert_at_pos (SV * self, int pos, SV * data) {
	dTHX;
	if (_is_undef(self)) {
		return _set_data(self, data);
	}

	self = _start(self);
	HV * hash = (HV*)SvRV(self);

	int i = 0;
	for (i = 0; i < pos; i++) {
		if (_defined(hash, "next", 4)) {
			self = *hv_fetch(hash, "next", 4, 0);
			hash = (HV*)SvRV(self);
		}
	}

	return _insert_after(self, data);
}

SV * _insert_at_start (SV * self, SV * data) {
	dTHX;
	if (_is_undef(self)) {
		return _set_data(self, data);
	}

	self = _start(self);
	HV * hash = (HV*)SvRV(self);
	
	SV * node = _new(self, data);
	HV * hash_node = (HV*)SvRV(node);

	*hv_store(hash_node, "next", 4, newSVsv(self), 0);
	*hv_store(hash, "prev", 4, newSVsv(node), 0);

	return node;
}

SV * _insert_at_end (SV * self, SV * data) {
	dTHX;
	if (_is_undef(self)) {
		return _set_data(self, data);
	}

	self = _end(self);
	HV * hash = (HV*)SvRV(self);

	SV * node = _new(self, data);
	HV * hash_node = (HV*)SvRV(node);

	*hv_store(hash_node, "prev", 4, newSVsv(self), 0);
	*hv_store(hash, "next", 4, newSVsv(node), 0);

	return node;
}

SV * _remove (SV * self) {
	dTHX;

	if (_is_undef(self)) {
		return &PL_sv_undef;
	}

	HV * hash = (HV*)SvRV(self);
	SV * undef = &PL_sv_undef;
	SV * prev = *hv_fetch(hash, "prev", 4, 0);
	SV * next = *hv_fetch(hash, "next", 4, 0);
	SV * data;

	if (SvOK(prev) || SvOK(next)) {
		if (SvOK(prev)) {
			HV * previous = (HV*)SvRV(prev);
			data = newSVsv(prev);
			if (SvROK(next)) {
				HV * nexting = (HV*)SvRV(next);
				*hv_store(previous, "next", 4, newSVsv(next), 0);
				*hv_store(nexting, "prev", 4, newSVsv(prev), 0);	
			} else {
				*hv_store(previous, "next", 4, undef, 0);
			}
		} else if (SvOK(next)) {
			data = newSVsv(next);
			HV * nexting = (HV*)SvRV(next);
			*hv_store(nexting, "prev", 4, undef, 0);
		}
	} else {
		*hv_store(hash, "data", 4, undef, 0);
		data = newSVsv(self);
	}

	return data;
}

SV * _remove_from_start(SV * self) {
	if (_is_undef(self)) {
		return &PL_sv_undef;
	}

	self = _start(self);

	return _remove(self);
}

SV * _remove_from_end(SV * self) {
	if (_is_undef(self)) {
		return &PL_sv_undef;
	}

	self = _end(self);

	return _remove(self);
}

SV * _remove_from_pos (SV * self, int pos) {
	if (_is_undef(self)) {
		return &PL_sv_undef;
	}

	self = _start(self);
	HV * hash = (HV*)SvRV(self);

	int i = 0;
	for (i = 0; i < pos; i++) {
		if (_defined(hash, "next", 4)) {
			self = *hv_fetch(hash, "next", 4, 0);
			hash = (HV*)SvRV(self);
		}
	}

	return _remove(self);
}


MODULE = Doubly::Linked  PACKAGE = Doubly::Linked
PROTOTYPES: ENABLE
FALLBACK: TRUE

SV *
new(...)
	CODE: 
		RETVAL = _new(ST(0), items > 1 ? newSVsv(ST(1)) : &PL_sv_undef);
	OUTPUT:
		RETVAL

SV *
data(self, ...)
	SV * self
	CODE:
		HV * hash = (HV*)SvRV(self);
		if (items > 1) {
			*hv_store(hash, "data", 4, newSVsv(ST(1)), 0);
		}
		SV * data = newSVsv(*hv_fetch(hash, "data", 4, 0));
		RETVAL = data;
	OUTPUT:
		RETVAL

SV *
start(self)
	SV * self
	CODE:
		RETVAL = newSVsv(_start(self));
	OUTPUT:
		RETVAL

SV *
is_start(self)
	SV * self
	CODE:
		RETVAL = _is_start(self);
	OUTPUT:
		RETVAL

SV *
end(self)
	SV * self
	CODE:
		RETVAL = newSVsv(_end(self));
	OUTPUT:
		RETVAL

SV *
is_end(self)
	SV * self
	CODE:
		RETVAL = _is_end(self);
	OUTPUT:
		RETVAL

SV *
next(self)
	SV * self
	CODE:
		HV * hash = (HV*)SvRV(self);
		SV * next = newSVsv(*hv_fetch(hash, "next", 4, 0));
		RETVAL = next;
	OUTPUT:
		RETVAL

SV *
prev(self)
	SV * self
	CODE:
		HV * hash = (HV*)SvRV(self);
		SV * prev = newSVsv(*hv_fetch(hash, "prev", 4, 0));
		RETVAL = prev;
	OUTPUT:
		RETVAL

SV *
add(self, ...)
	SV * self
	CODE:
		RETVAL = _insert_at_end(self, newSVsv(ST(1)));
	OUTPUT:
		RETVAL

SV *
insert(self, cb, ...)
	SV * self
	SV * cb
	CODE:
		RETVAL = _insert(self, cb, newSVsv(ST(2)));
	OUTPUT:
		RETVAL

SV * 
insert_before(self, ...)
	SV * self
	CODE:
		RETVAL = _insert_before(self, newSVsv(ST(1)));
	OUTPUT:
		RETVAL

SV * 
insert_after(self, ...)
	SV * self
	CODE:
		RETVAL = _insert_after(self, newSVsv(ST(1)));
	OUTPUT:
		RETVAL

SV *
insert_at_start(self, ...)
	SV * self
	CODE:
		RETVAL = _insert_at_start(self, newSVsv(ST(1)));
	OUTPUT:
		RETVAL

SV *
insert_at_end(self, ...)
	SV * self
	CODE:
		RETVAL = _insert_at_end(self, newSVsv(ST(1)));
	OUTPUT:
		RETVAL

SV *
insert_at_pos(self, ...)
	SV * self
	CODE:
		RETVAL = _insert_at_pos(self, SvIV(ST(1)), newSVsv(ST(2)));
	OUTPUT:
		RETVAL

SV *
remove(self)
	SV * self
	CODE:
		RETVAL = _remove(self);
	OUTPUT:
		RETVAL

SV *
remove_from_start(self)
	SV * self
	CODE:
		RETVAL = _remove_from_start(self);
	OUTPUT:
		RETVAL

SV *
remove_from_end(self)
	SV * self
	CODE:
		RETVAL = _remove_from_end(self);
	OUTPUT:
		RETVAL

SV *
remove_from_pos(self, ...)
	SV * self
	CODE:
		RETVAL = _remove_from_pos(self, SvIV(ST(1)));
	OUTPUT:
		RETVAL

SV *
find(self, cb)
	SV * self
	SV * cb
	CODE:
		RETVAL = _find(self, cb);
	OUTPUT:
		RETVAL
