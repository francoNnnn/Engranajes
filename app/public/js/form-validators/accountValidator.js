
function AccountValidator()
{
// build array maps of the form inputs & control groups //

	this.formFields = [$('#name-tf'), $('#email-tf'), $('#user-tf'), $('#pass-tf')];
	this.controlGroups = [$('#name-cg'), $('#email-cg'), $('#user-cg'), $('#pass-cg')];
	
// bind the form-error modal window to this controller to display any errors //
	
	this.alert = $('.modal-form-errors');
	this.alert.modal({ show : false, keyboard : true, backdrop : true});
	
	this.validateName = function(s)
	{
		return s.length >= 3;
	}
	
	this.validatePassword = function(s)
	{
	// if user is logged in and hasn't changed their password, return ok
		if ($('#userId').val() && s===''){
			return true;
		}	else{
			return s.length >= 6;
		}
	}
	
	this.validateEmail = function(e)
	{
		var re = /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
		return re.test(e);
	}
	
	this.showErrors = function(a)
	{
		$('.modal-form-errors .modal-body p').text('Corrige los siguientes problemas por favor :');
		var ul = $('.modal-form-errors .modal-body ul');
			ul.empty();
		for (var i=0; i < a.length; i++) ul.append('<li>'+a[i]+'</li>');
		this.alert.modal('show');
	}

}

AccountValidator.prototype.showInvalidEmail = function()
{
	this.controlGroups[1].addClass('error');
	this.showErrors(['Esta dirección de email ya está siendo usada.']);
}

AccountValidator.prototype.showInvalidUserName = function()
{
	this.controlGroups[2].addClass('error');
	this.showErrors(['Este nombre de usuario ya existe.']);
}

AccountValidator.prototype.validateForm = function()
{
	var e = [];
	for (var i=0; i < this.controlGroups.length; i++) this.controlGroups[i].removeClass('error');
	if (this.validateName(this.formFields[0].val()) == false) {
		this.controlGroups[0].addClass('error'); e.push('Ingresa tu nombre por favor');
	}
	if (this.validateEmail(this.formFields[1].val()) == false) {
		this.controlGroups[1].addClass('error'); e.push('Ingresa una dirección de email válida');
	}
	if (this.validateName(this.formFields[2].val()) == false) {
		this.controlGroups[2].addClass('error');
		e.push('Elige tu nombre de usuario');
	}
	if (this.validatePassword(this.formFields[3].val()) == false) {
		this.controlGroups[3].addClass('error');
		e.push('Tu contraseña debería tener al menos 6 caracteres');
	}
	if (e.length) this.showErrors(e);
	return e.length === 0;
}

	